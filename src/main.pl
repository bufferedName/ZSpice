#!/usr/bin/perl -w
use strict;
use lib 'src/lib';
use Getopt::Long;
use Log::Dispatch;
use Log::Dispatch::Screen;
use File::Copy;
use File::Path  qw(remove_tree);
use Time::HiRes qw(gettimeofday tv_interval);
require TreeNode;

my $start_time = [gettimeofday];

my $inputFolderName = './examples';

my $logger = Log::Dispatch->new;

my $modelPath = './src/lib/model';
my $modelName;
my $modelNameDefault = 'SC';

my $processPath = './src/lib/process';
my $processName;
my $processNameDefault = 'sm046005-1j.hspice';

my $voltageDefault = 3.3;

my $timescaleDefault      = "ns";
my $testbenchStepDefault  = 0.01;
my $testbenchPulseDefault = 10;

my $CapacitorLoadDefault = "0.01pF";

our $subcktCount = 1000;

my %global_param = (
    LN => '0.35u',
    LP => '0.35u',
    WN => '1u',
    WP => '3.5u',
);

my %symbols = (
    '~' => { name => "INV", priority => 4 },
    '&' => { name => "AND", priority => 3 },
    '^' => { name => "XOR", priority => 2 },
    '|' => { name => "OR",  priority => 1 },

    #'?:' => { name => "MUX" },
);

#----------------Parsing Command Arguments-----------------#

my $verbose = 0;
my $outputFileName;
my $topModuleFileName;
my $needTestBench;
my $voltage;
my $timescale;
my $testbenchStep;
my $testbenchPulse;
my $CapacitorLoad;
my $needClearCache;
my %options = (
    'verbose|v'       => '\$verbose',
    'output|o=s'      => '\$outputFileName',
    'top=s'           => '\$topModuleFileName',
    'model|m=s'       => '\$modelName',
    'process|p=s'     => '\$processName',
    'testbench|t'     => '\$needTestBench',
    'voltage=s'       => '\$voltage',
    'timescale=s'     => '\$timescale',
    'tbStep=s'        => '\$testbenchStep',
    'tbPulse=s'       => '\$testbenchPulse',
    'capacitorload=s' => '\$CapacitorLoad',
    'clearCache'      => '\$needClearCache',

);

my $evalCommand = "";
foreach my $key ( keys %global_param ) {
    $evalCommand .= "my \$$key;\n";
    print $@;
}
$evalCommand .= "GetOptions(";
foreach my $key ( keys %options ) {
    $evalCommand .= "\'$key\' => $options{$key}, ";
}

foreach my $key ( keys %global_param ) {
    $evalCommand .= "\'$key=s\'=> \\\$$key, ";
}
$evalCommand .= ") or die \"Unknown param\\n\";\n";
foreach my $key ( keys %global_param ) {
    $evalCommand .= '$global_param{' . $key . '}' . " = \$$key ? \$$key : \"$global_param{$key}\";\n";
}
eval $evalCommand;
if ($@) { die $@ }
print $@;
$logger->add(
    Log::Dispatch::Screen->new(
        name      => 'screen_log',
        min_level => ( $verbose ? 'debug' : 'info' ),
    )
);
$logger->info("Initalizing params...\n");
$logger->info("Global params:\n");
foreach my $key ( keys %global_param ) {
    $logger->info( "\t$key\t" . "$global_param{$key}\n" );
}
if ( !$modelName ) {
    $modelName = $modelNameDefault;
}
else {
    if ( !( -d "$modelPath/$modelName" ) ) {
        die "Cannot find model library '$modelName'\n";
    }
}
$logger->info("Model_name:\t\t\t\t\t$modelPath/$modelName\n");
if ( !$processName ) { $processName = $processNameDefault; }
$logger->info("Process_name:\t\t\t\t\t$processPath/$processName\n");
if ( !$voltage ) { $voltage = $voltageDefault; }
$logger->info("Voltage:\t\t\t\t\t$voltage V\n");
if ( !$timescale ) { $timescale = $timescaleDefault; }
$logger->info("Transient_analysis_timescale:\t\t\t$timescale\n");
if ( !$testbenchStep ) { $testbenchStep = $testbenchStepDefault; }
$logger->info("Transient_analysis mininum_step:\t\t$testbenchStep $timescale\n");
if ( !$testbenchPulse ) { $testbenchPulse = $testbenchPulseDefault; }
$logger->info("Transient_analysis_voltage_source_pulsewidth:\t$testbenchPulse $timescale\n");
if ( !$CapacitorLoad ) { $CapacitorLoad = $CapacitorLoadDefault; }
$logger->info("Transient_analysis_output_load_capacitor:\t$CapacitorLoad\n");

if (@ARGV) {
    $inputFolderName = shift @ARGV;
}
$logger->info("\nReading input files...\n");
$logger->info("Input_path:\t\t\t\t\t$inputFolderName\n");
opendir( my $dh, $inputFolderName )
  or die "Cannot open directory '$inputFolderName': $!\n";
my @inputFileNames = readdir($dh);
my @inputFileNamesSpice;
closedir($dh);
@inputFileNamesSpice = grep { !(/^\.\.?$/) && /\.sp$|\.spice$/i } @inputFileNames;
@inputFileNames      = grep { !(/^\.\.?$/) && /\.v$|\.V$/ } @inputFileNames;
$logger->info( "Found verilog file(s):\n\t" . join( "\n\t", @inputFileNames ) . "\n" );
$logger->info( "Found spice file(s):\n\t" . join( "\n\t", @inputFileNamesSpice ) . "\n" );

if ( !(@inputFileNames) ) {
    die "Cannot find any Verilog files (*.v or *.V)\n";
}
if ($topModuleFileName) {
    if ( !( grep { $_ eq $topModuleFileName } @inputFileNames ) ) {
        die "Cannot find top_module file '$topModuleFileName': $!\n";
    }
}
else {
    if ( @inputFileNames == 1 ) {
        $topModuleFileName = $inputFileNames[0];
        $logger->log(
            level   => 'info',
            message => "Automatically pick '$topModuleFileName' as top_module file\n"
        );
    }
    else {
        my @tops = grep { /(?![_])top/i } @inputFileNames;
        if (@tops) {
            $topModuleFileName = $tops[0];
            $logger->log(
                level   => 'info',
                message => "Automatically pick '$topModuleFileName' as top_module file\n"
            );
        }
        else {
            die "Ambiguous top_module file name\n";
        }
    }
}
if ( !$outputFileName ) {
    $topModuleFileName =~ /^(.*)\.(v|V)$/;
    $outputFileName = $1 . ".sp";
    $logger->log(
        level   => 'info',
        message => "Automatically pick '$outputFileName' as output file name\n"
    );
}
$logger->info("Top-module file:\t$inputFolderName/$topModuleFileName\n");

#----------------------------------------------------------#

#---------------Establishing Output Folder-----------------#

$logger->info("\nEstablishing output folder...\n");
my $outputFolderName = "$inputFolderName/output";
unless ( -d $outputFolderName ) {
    mkdir $outputFolderName
      or die "Cannot create folder '$outputFolderName': $! \n";
}

$outputFileName = "$outputFolderName/$outputFileName";
copy( "$processPath/$processName", "$outputFolderName/$processName" )
  or die "Cannot copy process library '$processPath/$processName': $!\n";
$logger->info("Output path:\t$outputFolderName\n");
$logger->info("Output file:\t$outputFileName\n");
$logger->info("Process library $processPath/$processName copied into $outputFolderName/$processName\n");
my $bufferFolderName = "$outputFolderName/tmp";
if ( -d $bufferFolderName ) {
    remove_tree( $bufferFolderName, { error => \my $error } );
    foreach (@$error) {
        $logger->warning("Unable to delete cache file $error->[0]: $error->[1]\n");
    }
    $logger->info("Cache file cleared\n");
}
unless ( -d $bufferFolderName ) {
    mkdir $bufferFolderName
      or die "Cannot create folder '$bufferFolderName': $! \n";
}
$logger->info("Temporary workplace path:\t$bufferFolderName\n");
my $noUTF8BOMFolderName = $bufferFolderName . "/noUTF8BOM";
unless ( -d $noUTF8BOMFolderName ) {
    mkdir $noUTF8BOMFolderName
      or die "Cannot create folder '$noUTF8BOMFolderName': $! \n";
}
foreach ( ( @inputFileNames, @inputFileNamesSpice ) ) {
    open( my $fh, "<", "$inputFolderName/$_" )
      or die "Unable to read '$inputFolderName/$_' $!";
    open( my $fhout, ">", "$noUTF8BOMFolderName/$_" )
      or die "Cannot open '$noUTF8BOMFolderName/$_' $!";
    my $content = do { local $/; <$fh> };
    if ( $content =~ /^\x{EF}\x{BB}\x{BF}/ ) {
        $content =~ s/^\x{EF}\x{BB}\x{BF}//;
        $logger->debug("Cropped UTF-8 BOM of file '$_'\n");
    }
    print $fhout $content;
    close $fh;
    close $fhout;
}
$inputFolderName = $noUTF8BOMFolderName;

#----------------------------------------------------------#

#----------------Pre-process Input File--------------------#
$logger->info("\nPre-processing input file...\n");
my $buses = {};

sub cropStr {
    my $loggerRes = shift;
    my $length    = shift;
    $loggerRes =~ s/\n/ /g;
    if ( not defined $length ) {
        $length = 6;
    }
    return $loggerRes if length($loggerRes) <= ( 2 * $length );
    return substr( $loggerRes, 0, $length ) . "\t...\t" . substr( $loggerRes, -$length );
}

sub parseBus {

    sub to_bin {
        my $digit    = shift;
        my $encoding = shift;
        my $content  = shift;
        if ( $encoding =~ /h/i ) {
            $content  = hex($content);
            $encoding = "d";
        }
        if ( $encoding =~ /d/i ) {
            $content = sprintf( "%b", $content );
        }
        $content = sprintf( '%0' . $digit . 'd', $content );
        $content = substr( $content, -$digit );
        return $content;
    }

    my $fullname  = shift;
    my $linecount = shift;
    my $filename  = shift;
    my $res       = [];
    my $msb       = 0;
    my $lsb       = 0;
    my $loggerRes = "";
    $fullname =~ /^\s*(?<name>[a-zA-Z]\w*)(?:\s*(?:\[\s*(?<msb>\d+)\s*:\s*(?<lsb>\d+)\s*\]|\[\s*(?<index>\d+)\s*\]))?\s*$/;

    if ( $+{name} ) {
        if ( exists $buses->{ $+{name} } ) {
            if ( defined $+{msb} ) {
                $msb = $+{msb};
                $lsb = $+{lsb};
                foreach ( $+{lsb} .. $+{msb} ) {
                    push @{$res}, ( $+{name} . "_$_" );
                }
            }
            elsif ( defined $+{index} ) {
                $msb = $+{index};
                $lsb = $+{index};
                push @{$res}, ( $+{name} . "_" . $+{index} );
            }
            else {
                foreach ( $buses->{ $+{name} }->{LSB} .. $buses->{ $+{name} }->{MSB} ) {
                    push @{$res}, ( $+{name} . "_$_" );
                }
                $msb = $buses->{ $+{name} }->{LSB};
                $lsb = $buses->{ $+{name} }->{MSB};
            }
        }
        else {
            if ( $+{msb} || $+{index} ) {
                die "Undefined Bus '" . $+{name} . "' at '$inputFolderName/$filename'";
            }
            else {
                $msb = -1;
                push @{$res}, ( $+{name} );
            }
        }
        if ( @{$res} > 1 ) {
            $loggerRes .= join( ", ", @{$res} );
            $loggerRes = cropStr($loggerRes);
            $logger->debug("Parsed bus: $fullname \t => $loggerRes\n");
        }
        return $res;
    }
    $fullname =~ /(?<digit>\d+)'(?<encoding>b|h|d)(?<content>[\dA-Fa-f]+)/i;
    if ( $+{digit} ) {
        foreach (
            reverse
            split( //, to_bin( $+{digit}, $+{encoding}, $+{content} ) )
          )
        {
            push @{$res}, "1'b$_";
        }
        if ( @{$res} > 1 ) {
            $loggerRes .= join( ", ", @{$res} );
            $loggerRes = cropStr($loggerRes);
            $logger->debug("Parsed bus: $fullname \t => $loggerRes\n");
        }
        return $res;
    }
    return $fullname;
}
my $moduleDeclarations = {};

foreach my $filename (@inputFileNames) {
    open( my $fh, "<", "$inputFolderName/$filename" )
      or die "Unable to read $inputFolderName/$filename";
    open( my $fhout, ">", "$bufferFolderName/$filename" )
      or die "Cannot open $bufferFolderName/$filename";

    my $linecount         = 0;
    my $isDeclaringModule = 0;
    my $isCellModule      = 0;
    my $moduleDeclaration = "";
    my $moduleDefinition  = "";

    while ( my $line = <$fh> ) {

        sub declareBus {
            my $expr        = shift;
            my $moduleName  = shift;
            my $filename    = shift;
            my $declaration = shift;
            $expr =~ s/\n//g;
            $expr =~ /^(?<blank>\s*)(?<type>input|output|wire)\s*(?:\[\s*(?<msb>\d+)\s*:\s*(?<lsb>\d+)\s*\])?\s*(?<names>[a-zA-Z]\w*(?:\s*,\s*[a-zA-Z]\w*)*)\s*(?<end>[,;]?)\s*/;
            my $allnames = $+{names};
            my $LSB      = $+{lsb};
            my $MSB      = $+{msb};
            my $type     = $+{type};
            my $end      = $+{end};
            my $blank    = $+{blank};
            my @names    = $allnames =~ /([a-zA-Z]\w*)/g;

            if ( !defined $MSB ) {
                if ($declaration) {
                    foreach (@names) {
                        push @{ $declaration->{$type} }, $_;
                    }
                }
                return $expr . "\n";
            }

            my $width = $MSB - $LSB + 1;
            foreach (@names) {
                $buses->{$_} = { name => $_, LSB => $LSB, MSB => $MSB, type => $type, width => $width };
                $logger->debug("Bus declared:\{name =>\t$_,\tLSB =>\t$LSB,\tMSB =>\t$MSB,\ttype =>\t$type,\twidth =>\t$width\}\tin module '$moduleName' of file '$filename'\n");
            }
            my $res = "";
            foreach my $index ( $LSB .. $MSB ) {
                if ( !$blank ) {
                    $blank = "\t";
                }
                $res .= "$blank$type";
                my $notFirst = 0;
                foreach my $name (@names) {
                    $res .= " ";
                    if ($notFirst) {
                        $res .= ",";
                    }
                    else {
                        $notFirst = 1;
                    }
                    $res .= $name . "_$index";
                    if ($declaration) {
                        push @{ $declaration->{$type} }, $name . "_$index";
                    }
                }
                if ( $index != $MSB || $end ) {
                    $res .= ( ( $type eq "wire" ) ? ";" : "," );
                }
                $res .= "\n";
            }
            return $res;

        }

        $linecount += 1;
        if ( $line =~ /^\s*\/\// ) {    #comments
            next;
        }
        elsif ( $line =~ /^\s*`celldefine/ ) {
            $isCellModule = 1;
        }
        elsif ( $line =~ /^\s*`endcelldefine/ ) {
            $isCellModule = 0;
        }
        elsif ( $line =~ /^\s*module\s*/ ) {
            $isDeclaringModule = 1;
        }
        if ($isDeclaringModule) {
            $moduleDeclaration .= $line;
            if ( $moduleDeclaration =~ /module\s+(?<name>[a-zA-Z]\w*)\s*\((?<io>[^\(\)]*)\)\s*;(?<content>(?:(?!\smodule\s).)*)endmodule/gs ) {
                $isDeclaringModule = 0;
                my $name    = $+{name};
                my $io      = $+{io};
                my $content = $+{content};
                if ( exists $moduleDeclarations->{$name} ) {
                    die "Multiple Definition found of module '$name'\n";
                }
                $moduleDeclarations->{$name} = { name => $name, input => [], output => [], file => $filename, isCellModule => $isCellModule, cellDefinition => "" };

                #io bus seperation
                my @ios = $io =~ /(\s*(?:input|output)\s*(?:\[\s*\d+\s*:\s*\d+\s*\])?\s*(?!input\b)(?!output\b)[a-zA-Z]\w*(?:\s*,\s*(?!input\b)(?!output\b)[a-zA-Z]\w*)*\s*[,;]?\s*)/g;
                $io = "";
                foreach (@ios) {
                    $io .= declareBus( $_, $name, $filename, $moduleDeclarations->{$name} );
                }

                #wire bus seperation
                my @bus = $content =~ /(\s*wire\s*\[\s*\d+\s*:\s*\d+\s*\]\s*(?!wire\b)[a-zA-Z]\w*(?:\s*,\s*(?!wire\b)[a-zA-Z]\w*)*\s*[,;]?\s*)/g;
                foreach my $wire (@bus) {
                    my $res = declareBus( $wire, $name, $filename );
                    $content =~ s/$wire/$res/;
                }

                #assign bus seperation
                my @assigns = $content =~ /(\s*assign\s+[a-zA-Z]\w*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*=\s*(?:(?:(?:(?<!\d)\w+(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?)|(?:[()~&|^])|(?:\d+'(?:b|h|d)[\dA-Fa-f]+))\s*)+;)/gi;
                foreach my $assign (@assigns) {
                    my $res          = "";
                    my $originAssign = $assign;
                    $assign =~ s/\n//g;
                    $assign =~ /^(?<blank>\s*)assign\s+(?<fullname>[a-zA-Z]\w*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?)\s*=\s*(?<expr>(?:(?:(?:(?<!\d)\w+(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?)|(?:[()~&|^])|(?:\d+'(?:b|h|d)[\dA-Fa-f]+))\s*)+);/i;
                    my $blank    = $+{blank};
                    my $fullname = $+{fullname};
                    my $expr     = $+{expr};
                    my @tokens   = $expr =~ /(?:((?:[a-zA-Z]\w*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?)|(?:[()~&|^])|(?:\d+'(?:b|h|d)[\dA-Fa-f]+))\s*)/gi;
                    my @parsedTokens;

                    foreach (@tokens) {
                        push @parsedTokens, parseBus( $_, $linecount, $filename );
                    }
                    $fullname = parseBus( $fullname, $linecount, $filename );
                    my $busWidth = @{$fullname};
                    foreach (@parsedTokens) {
                        if ( ref($_) ) {
                            if ( @{$_} != $busWidth ) {
                                die "Ambiguous bus-width declared at '$inputFolderName/$filename' in expr '$assign'";
                            }
                        }
                    }
                    foreach my $index ( 0 .. $busWidth - 1 ) {
                        $res .= $blank . "assign " . $fullname->[$index] . " =";
                        foreach (@parsedTokens) {
                            $res .= " " . ( ref($_) ? ( $_->[$index] ) : $_ );
                        }
                        $res .= ";\n";
                    }
                    my $res .= "\n\n";
                    my $pos = index( $content, $originAssign );
                    substr( $content, $pos, length($originAssign), $res );
                }

                $moduleDeclarations->{$name}->{content} = $content;
                $moduleDeclarations->{$name}->{bus}     = $buses;
                $moduleDeclarations->{$name}->{ioStr}   = $io;
                $buses                                  = {};
                $moduleDeclaration                      = "";

                if ($isCellModule) {
                    my @subckts;
                    foreach (@inputFileNamesSpice) {
                        open( my $fspice, "<", "$inputFolderName/$_" ) or die "Cannot read file '$inputFolderName/$_' $! \n";
                        my $content = do { local $/; <$fspice> };
                        $content .= "\n";
                        my @subckt = $content =~ /(\.SUBCKT\s+$name\s+.*\.ENDS\s+$name\s+)/gsi;
                        close $fspice;
                        @subckts = ( @subckts, @subckt );
                    }
                    if ( @subckts > 1 ) {
                        die "Multiple sub-circuit '$name' defined in spice files\n";
                    }
                    elsif ( @subckts == 0 ) {
                        die "No sub-circuit '$name' definition found in spice files\n";
                    }
                    my $subckt = $subckts[0];
                    $subckt =~ /(?<ioName>\.SUBCKT[^\S\n]+$name(?<io>(?:[^\S\n]+\w+)+[^\S\n]*)\n)/i;
                    my $ioName = $+{ioName};
                    my $pos    = index( $subckt, $ioName );
                    substr( $subckt, $pos, length($ioName), $ioName . ".LIB $processName typical\n" );
                    my @ioNames = $+{io} =~ /(\b\w+)/g;

                    if ( @ioNames != @{ $moduleDeclarations->{$name}->{input} } + @{ $moduleDeclarations->{$name}->{output} } ) {
                        die "Ambiguous declaration of sub-circuit and module '$name'";
                    }
                    $moduleDeclarations->{$name}->{cellDefinition} = $subckt;
                    $logger->debug( "Cell module '$name' sub-circuit defined ('" . cropStr( $subckt, 20 ) . "')\n" );
                }
                $logger->debug("Module '$name' declared\n");
            }
        }
    }
    close $fh;
}
foreach my $filename (@inputFileNames) {
    open( my $fhout, ">", "$bufferFolderName/$filename" )
      or die "Cannot open '$bufferFolderName/$filename' $!\n";
    open( my $fhin, "<", "$inputFolderName/$filename" )
      or die "Unable to read '$inputFolderName/$filename' $!\n";
    while ( my $line = <$fhin> ) {
        if ( $line =~ /`include/i ) {
            print $fhout $line;
        }
    }
    close $fhin;

    foreach my $name ( keys %{$moduleDeclarations} ) {
        if ( $moduleDeclarations->{$name}->{file} eq $filename ) {
            my $content = $moduleDeclarations->{$name}->{content};
            $buses = $moduleDeclarations->{$name}->{bus};

            # module instance array seperation
            my @instances = $content =~ /(\s*[a-zA-Z]\w*\s*[a-zA-Z]\w*\s*\[\s*\d+\s*:\s*\d+\s*\]\s*\(\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))(?:\s*,\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))*\s*\)))*\s*\)\s*;)/g;
            foreach my $instance (@instances) {
                my $res            = "";
                my $originInstance = $instance;
                $instance =~ s/\n//g;
                $instance =~ /(?<blank>\s*)(?<moduleName>[a-zA-Z]\w*)\s*(?<instanceName>[a-zA-Z]\w*)\s*\[\s*(?<msb>\d+)\s*:\s*(?<lsb>\d+)\s*\]\s*\(\s*(?<io>(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))(?:\s*,\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))*\s*\)))*)\s*\)\s*;/;
                my $msb          = $+{msb};
                my $lsb          = $+{lsb};
                my $width        = $msb - $lsb + 1;
                my $blank        = $+{blank};
                my $moduleName   = $+{moduleName};
                my $instanceName = $+{instanceName};
                my $io           = $+{io};

                if ( !exists $moduleDeclarations->{$moduleName} ) {
                    die "Undefined module '$moduleName' at '$filename' in expr '$instance'\n";
                }
                my @ios = $io =~ /(\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))/g;
                my %ioMap;
                foreach my $io (@ios) {
                    $io =~ /\.(?<ioName>[a-zA-Z]\w*)\s*\((?<ioPort>(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?))\s*\)/;
                    my $ioName = $+{ioName};
                    my $ioPort = $+{ioPort};
                    $ioPort =~ /^\s*(?<name>[a-zA-Z]\w*)(?:\s*(?:\[\s*(?<msb>\d+)\s*:\s*(?<lsb>\d+)\s*\]|\[\s*(?<index>\d+)\s*\]))?\s*$/;
                    my $portWidth;
                    my $lsb = $+{lsb};
                    if ( defined $+{msb} ) {
                        $portWidth = $+{msb} - $+{lsb} + 1;
                        $lsb       = $+{lsb};
                    }
                    elsif ( defined $+{index} ) {
                        $portWidth = 1;
                        $lsb       = $+{index};
                    }
                    else {
                        if ( exists $buses->{$ioPort} ) {
                            $portWidth = $buses->{$ioPort}->{width};
                            $lsb       = $buses->{$ioPort}->{LSB};
                        }
                        else {
                            $portWidth = 1;
                        }
                    }
                    my $modulePortWidth;
                    if ( exists $moduleDeclarations->{$moduleName}->{bus}->{$ioName} ) {
                        $modulePortWidth = $moduleDeclarations->{$moduleName}->{bus}->{$ioName}->{width};
                    }
                    else {
                        $modulePortWidth = 1;
                    }
                    if ( $portWidth != $width * $modulePortWidth ) {
                        die "Ambiguous bus-width of net '$ioPort' declared at '$inputFolderName/$filename' in expr '$instance'\n";
                    }
                    $ioMap{$ioName} = { portName => $+{name}, LSB => $lsb, width => $modulePortWidth };
                }
                foreach my $index ( $lsb .. $msb ) {
                    $res .= $blank . $moduleName . " $instanceName" . "_$index(";
                    my $notFirst = 0;
                    foreach ( keys %ioMap ) {
                        if ($notFirst) {
                            $res .= ", ";
                        }
                        else {
                            $notFirst = 1;
                        }
                        $res .= ".$_(" . $ioMap{$_}->{portName} . "[" . ( $ioMap{$_}->{LSB} + ( $index - $lsb + 1 ) * $ioMap{$_}->{width} - 1 ) . ":" . ( $ioMap{$_}->{LSB} + ( $index - $lsb ) * $ioMap{$_}->{width} ) . "])";
                    }
                    $res .= ");\n";
                }
                $res .= "\n\n";
                my $pos = index( $content, $originInstance );
                substr( $content, $pos, length($originInstance), $res );
                $res =~ s/\n/ /gs;
                $res = cropStr( $res, 30 );
                $logger->debug("Seperate module instance array '$instance' => $res\n");
            }

            # module instance bus seperation
            @instances = $content =~ /(\s*[a-zA-Z]\w*\s*[a-zA-Z]\w*\s*\(\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))(?:\s*,\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))*\s*\)))*\s*\)\s*;)/g;
            foreach my $instance (@instances) {
                my $res            = "";
                my $originInstance = $instance;
                $instance =~ s/\n//g;
                $instance =~ /(?<blank>\s*)(?<moduleName>[a-zA-Z]\w*)\s*(?<instanceName>[a-zA-Z]\w*)\s*\(\s*(?<io>(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))(?:\s*,\s*(?:\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))*\s*\)))*)\s*\)\s*;/;
                my $blank        = $+{blank};
                my $moduleName   = $+{moduleName};
                my $instanceName = $+{instanceName};
                my $io           = $+{io};

                if ( !exists $moduleDeclarations->{$moduleName} ) {
                    die "Undefined module '$moduleName' at '$filename' in expr '$instance'\n";
                }
                my @ios = $io =~ /(\.[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?\s*\))/g;
                $res = "$blank$moduleName $instanceName(";
                my $notFirst = 0;
                foreach $io (@ios) {
                    $io =~ /\.(?<ioName>[a-zA-Z]\w*)\s*\((?<ioPort>(\s*[a-zA-Z]\w*\s*(?:\s*(?:\[\s*\d+\s*:\s*\d+\s*\]|\[\s*\d+\s*\]))?))\s*\)/;
                    my $ioName = $+{ioName};
                    my $ioPort = $+{ioPort};
                    if ($notFirst) {
                        $res .= ",";
                    }
                    else {
                        $notFirst = 1;
                    }
                    $res .= "\n";
                    if ( exists $moduleDeclarations->{$moduleName}->{bus}->{$ioName} ) {
                        my $parsedBus = parseBus($ioPort);
                        if ( $moduleDeclarations->{$moduleName}->{bus}->{$ioName}->{width} != @{$parsedBus} ) {
                            die "Ambiguous bus-width of net '$ioPort' declared at '$inputFolderName/$filename' in expr '$instance'\n";
                        }
                        my $notFirst = 0;
                        foreach ( $moduleDeclarations->{$moduleName}->{bus}->{$ioName}->{LSB} .. $moduleDeclarations->{$moduleName}->{bus}->{$ioName}->{MSB} ) {
                            if ($notFirst) {
                                $res .= ",";
                            }
                            else {
                                $res .= "$blank\t";
                                $notFirst = 1;
                            }
                            my $name = $parsedBus->[$_];
                            $res .= ".$ioName" . "_$_($name)";
                        }
                    }
                    else {
                        my $parsedBus = parseBus($ioPort);
                        if ( @{$parsedBus} != 1 ) {
                            die "Ambiguous bus-width declared at '$inputFolderName/$filename' in expr '$instance'\n";
                        }
                        my $name = $parsedBus->[0];
                        $res .= "$blank\t.$ioName" . "($name)";
                    }
                }
                $res .= "\n$blank);";
                my $res = "\n$res";
                my $pos = index( $content, $originInstance );
                substr( $content, $pos, length($originInstance), $res );
                $res =~ s/\n/ /gs;
                $res = cropStr( $res, 30 );
                $logger->debug("Seperate buses of module instance '$instance' => $res\n");
            }
            my $io = $moduleDeclarations->{$name}->{ioStr};
            $moduleDeclarations->{$name}->{content} = $content;
            print $fhout "module $name(\n$io\n);$content\nendmodule\n\n\n";
            $logger->info("Wrote module '$name' definition into file '$bufferFolderName/$filename'\n");
        }
    }
    close $fhout;
}
$inputFolderName = $bufferFolderName;

#----------------------------------------------------------#

#----------------Pre-process Output File-------------------#
$logger->info("\nPre-processing output file...\n");
open( my $outputFileHandler, '>', $outputFileName )
  or die "Cannot open output file '$outputFileName': $!\n";
print $outputFileHandler ".LIB $processName typical\n";
print $outputFileHandler ".OPTION POST\n";
my $param = ".PARAM";
foreach ( keys %global_param ) {
    my $value = $global_param{$_};
    $param .= " $_=$value";
}
$logger->debug("Global param declaration '$param' added into output file\n");
print $outputFileHandler $param;
print $outputFileHandler "\n\n\n";
print $outputFileHandler ".GLOBAL VDD GND\nVDD VDD GND $voltage\n\n";
$logger->debug("Global voltage declaration 'VDD VDD GND $voltage' added into output file\n");
foreach ( keys %symbols ) {
    my $name = $symbols{$_}->{name};
    open( my $fh, "<", "$modelPath/$modelName/$name.sp" )
      or die "Cannot find model '$name' in model library '$modelName'\n";
    my $content = do { local $/; <$fh> };
    if ( $content =~ /^\x{EF}\x{BB}\x{BF}/ ) {
        $content =~ s/^\x{EF}\x{BB}\x{BF}//;
        $logger->debug("Cropped UTF-8 BOM of file '$modelPath/$modelName/$name.sp'\n");
    }
    $content =~ /(\.SUBCKT.*)/i;
    my $prefix = $1;
    $content =~ s/\.SUBCKT.*/$prefix\n\.LIB $processName typical/;
    print $outputFileHandler "$content\n\n";
    close $fh;
    $content = cropStr( $content, 15 );
    $logger->debug("Basic sub-circuit '$name' \tloaded into output file ('$content')\n");
}

#----------------------------------------------------------#

#-------------------Parsing top module---------------------#

$logger->info("\nParsing top module...\n");
my @moduleNames;
foreach ( keys %{$moduleDeclarations} ) {
    if ( $moduleDeclarations->{$_}->{file} eq $topModuleFileName ) {
        push @moduleNames, $_;
    }
}
my $topModuleName;
if ( (@moduleNames) == 1 ) {
    $topModuleName = $moduleNames[0];
    $logger->info("Top module:\t$topModuleName\n");
}
elsif ( (@moduleNames) == 0 ) {
    die "No module declaration found in top module '$topModuleFileName'\n";
}
else {
    my @tops = grep { /top/i } @moduleNames;
    if ( @tops == 1 ) {
        $topModuleName = $tops[0];
        $logger->log(
            level   => 'info',
            message => "Automatically pick '$topModuleName' as top module\n"
        );
    }
    else {
        die "Ambiguous top-module declaration in top module '$topModuleFileName'\n";
    }
}

@moduleNames = keys %{$moduleDeclarations};

#----------------------------------------------------------#

#---------------------MUX Derivation-----------------------#
# foreach (@inputFileNames) {
#     open( my $fh, "<", "$inputFolderName/$_" )
#       or die "Unable to read $inputFolderName/$_";
#     my $content = do { local $/; <$fh> };
#     my @muxContent;
#     while ( $content =~
# /(assign\s+\w+\s*=)\s*[^;]*((~?\(.+?\)|~?\w+)\s*\?\s*(~?\(.+?\)|~?\w+)\s*:\s*(~?\(.+?\)|~?\w+))[^;]*;/gs
#       )
#     {
#         push @muxContent, [$1,$2];
#     }
#     foreach(@muxContent){
#         my $prefix = $_->[0];
#         my $nodeOrigin = $_->[1];
#         my $nodeCount = TreeNode::get_tag();
#         my $nodeNew = "N$nodeCount";
#         $content =~s/$nodeOrigin/$nodeNew/;
#     }
#     close $fh;
# }

#----------------------------------------------------------#

#-----------------SubCircuit Generation--------------------#
$logger->info("\nGenerating sub-circuit(s)...\n");
foreach (@moduleNames) {
    my $name = $_;
    if ( $moduleDeclarations->{$name}->{isCellModule} ) {
        if ( $moduleDeclarations->{$name}->{cellDefinition} eq "" ) {
            die "Null sub-circuit definition of cell module '$name'\n";
        }
        print $outputFileHandler $moduleDeclarations->{$name}->{cellDefinition} . "\n";
        $logger->info( "Cell module '$name' sub-circuit loaded into output file ('" . cropStr( $moduleDeclarations->{$name}->{cellDefinition}, 20 ) . "')\n" );
        next;
    }
    my $content = $moduleDeclarations->{$name}->{content};
    my $subckt  = "";
    $subckt .= ".SUBCKT $name ";
    $subckt .= join( " ", @{ $moduleDeclarations->{$name}->{input} } );
    $subckt .= " ";
    $subckt .= join( " ", @{ $moduleDeclarations->{$name}->{output} } );
    $subckt .= "\n.LIB $processName typical\n";

    sub process_simple_assign {

        sub precedence {
            my $op = shift;
            if ( exists $symbols{$op} ) {
                if ( exists $symbols{$op}->{priority} ) {
                    return $symbols{$op}->{priority};
                }
                else {
                    return 0;
                }
            }
            else {
                return 0;
            }
        }

        sub buildTree {
            my @postfix = @_;
            my @stack;

            foreach my $token (@postfix) {
                if ( $token =~ /(?!\d)\w+|1'b1|1'b0/ ) {
                    if ( $token eq "1'b1" ) {
                        $token = "VDD";
                    }
                    elsif ( $token eq "1'b0" ) {
                        $token = "GND";
                    }
                    push @stack, TreeNode->new($token);
                }
                else {
                    my $node  = TreeNode->new($token);
                    my $left  = pop @stack;
                    my $right = pop @stack;
                    $node->new_child($left);
                    $node->new_child($right);
                    push @stack, $node;
                }
            }

            return pop @stack;
        }

        sub tokenize {
            my $expr = shift;
            $expr =~ s/~/1'b1 ~/g;
            my @tokens = $expr =~ /((?!\d)\w+|[()&|~^]|1'b1|1'b0)/g;
            return @tokens;
        }

        sub to_postfix {
            my @tokens = @_;
            my @postfixTokens;
            my @operators;

            foreach ( reverse @tokens ) {
                if ( $_ =~ /(?!\d)\w+|1'b1|1'b0/ ) {
                    push @postfixTokens, $_;
                }
                elsif ( $_ eq ')' ) {
                    push @operators, $_;
                }
                elsif ( $_ eq '(' ) {
                    while ( @operators && $operators[-1] ne ')' ) {
                        push @postfixTokens, pop @operators;
                    }
                    pop @operators;
                }
                else {
                    while (@operators) {
                        if ( precedence( $operators[-1] ) > precedence($_) ) {
                            push @postfixTokens, pop @operators;
                        }
                        else {
                            last;
                        }
                    }
                    push @operators, $_;
                }
            }
            while (@operators) {
                push @postfixTokens, pop @operators;
            }
            return @postfixTokens;
        }

        sub to_spice {
            my $netName   = shift;
            my $root      = shift;
            my $data      = $root->data();
            my $resString = "";
            if ( exists $symbols{$data} ) {
                my $name = $symbols{$data}->{name};
                $resString .= "X$name";
                $resString .= "$subcktCount";
                $subcktCount += 1;
                my ( $netName0, $netName1 );
                if ( $root->children()->[0]->has_child() ) {
                    $netName0 = $root->children()->[0]->tag();
                    $netName0 = "N$netName0";
                }
                else {
                    $netName0 = $root->children()->[0]->data();
                }
                if ( $root->children()->[1]->has_child() ) {
                    $netName1 = $root->children()->[1]->tag();
                    $netName1 = "N$netName1";
                }
                else {
                    $netName1 = $root->children()->[1]->data();
                }
                $resString .= " $netName0 $netName1 $netName $name\n";
                if ( $root->children()->[0]->has_child() ) {
                    $resString .= to_spice( $netName0, $root->children()->[0] );
                }
                if ( $root->children()->[1]->has_child() ) {
                    $resString .= to_spice( $netName1, $root->children()->[1] );
                }
            }
            else {
                if ( $data eq "1'b1" ) {
                    $resString .= "Rshort_";
                    $resString .= "$netName $netName VDD 0\n";
                }
                elsif ( $data eq "1'b0" ) {
                    $resString .= "Rshort_";
                    $resString .= "$netName $netName GND 0\n";
                }
                else {
                    $resString .= "Rshort_";
                    $resString .= "$netName $netName $data 0\n";
                }
            }

            return $resString;
        }
        my $netName = shift;
        my $expr    = shift;
        my $root    = buildTree( to_postfix( tokenize($expr) ) );
        return to_spice( $netName, $root );

    }
    while ( $content =~ /\s*assign\s+((?!\d)\w+)\s+=\s+([^;]+)\s*;/gs ) {    #simple assign
        my $assign = process_simple_assign( $1, $2 );
        $logger->debug( "Expr '$2' assign to wire '$1' parsed as '" . cropStr( $assign, 15 ) . "'\n" );
        $subckt .= $assign;
    }
    while ( $content =~ /(?<moduleName>[a-zA-Z]\w*)\s+(?<instanceName>[a-zA-Z]\w*)\s*\((?<ios>\s*\.\s*[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*\)(?:\s*,\s*\.\s*[a-zA-Z]\w*\s*\(\s*[a-zA-Z]\w*\s*\))*)\s*\)\s*;/gs ) {    #module instance
        my $name         = $+{moduleName};
        my $instanceName = $+{instanceName};
        my $io           = $+{ios};
        if ( exists $moduleDeclarations->{$name} ) {
            my $instance = "";
            $instance .= "X$instanceName$subcktCount ";
            $subcktCount += 1;
            foreach ( @{ $moduleDeclarations->{$name}->{input} } ) {
                if ( $io =~ /\.\s*$_\(\s*(\w+)\s*\)/ ) {
                    $instance .= "$1 ";
                }
                else {
                    my $nodeCount = TreeNode::get_tag();
                    $instance .= "N$nodeCount ";
                }
            }
            foreach ( @{ $moduleDeclarations->{$name}->{output} } ) {
                if ( $io =~ /\.\s*$_\(\s*(\w+)\s*\)/ ) {
                    $instance .= "$1 ";
                }
                else {
                    my $nodeCount = TreeNode::get_tag();
                    $instance .= "N$nodeCount ";
                }
            }
            $instance .= "$name\n";
            $subckt   .= $instance;
            $instance = "$instanceName($io)";
            $instance =~ s/\n| |\t//g;
            $logger->debug( "Module instance '$name $instance' parsed as '" . cropStr( $instance, 10 ) . "'\n" );
        }
    }
    $subckt .= ".ENDS $name\n\n";
    print $outputFileHandler $subckt;
    $logger->info( "Module '$name' parsed and loaded into output file ('" . cropStr( $subckt, 20 ) . "')\n" );
}

#----------------------------------------------------------#

#------------------TestBench Generation--------------------#
if ($needTestBench) {
    $logger->info("\nGenerating transient analysis testbench circuit...\n");
    print $outputFileHandler "\n\n";
    my $subckt = "";
    $subckt .= "X_TOP ";
    $subckt .= join( " ", @{ $moduleDeclarations->{$topModuleName}->{input} } );
    $subckt .= " ";
    $subckt .= join( " ", @{ $moduleDeclarations->{$topModuleName}->{output} } );
    $subckt .= " $topModuleName\n";
    print $outputFileHandler $subckt;
    $logger->info( "Sub-circuit for top-module generated as '" . cropStr( $subckt, 15 ) . "'\n" );

    foreach ( @{ $moduleDeclarations->{$topModuleName}->{output} } ) {
        print $outputFileHandler "C_$_ $_ GND $CapacitorLoad\n";
    }
    $logger->info("Load Capacitor(s) generated\n");
    print $outputFileHandler "\n\n";
    foreach ( @{ $moduleDeclarations->{$topModuleName}->{input} } ) {
        print $outputFileHandler "V_$_ $_ GND PULSE(0V $voltage";
        print $outputFileHandler "V $testbenchPulse$timescale 0$timescale 0$timescale $testbenchPulse$timescale ";
        $testbenchPulse *= 2;
        print $outputFileHandler "$testbenchPulse$timescale)\n";
    }
    $logger->info("Pulse votage source(s) generated\n");
    print $outputFileHandler "\n\n";
    print $outputFileHandler ".TRAN $testbenchStep$timescale $testbenchPulse$timescale\n";
    $logger->info("Transient analysis params generated as '.TRAN $testbenchStep$timescale $testbenchPulse$timescale'\n");
}

#----------------------------------------------------------#

print $outputFileHandler "\n.END\n";
close $outputFileHandler;

if ( $needClearCache && ( -d $bufferFolderName ) ) {
    remove_tree( $bufferFolderName, { error => \my $error } );
    foreach (@$error) {
        $logger->warning("Unable to delete cache file $error->[0]: $error->[1]\n");
    }
    $logger->info("\nCache file cleared\n");
}

$logger->info("\nGeneration done!\n");
my $end_time = [gettimeofday];
$logger->info( "Total time usage:\t" . tv_interval( $start_time, $end_time ) . " sec\n\n" );

1;
