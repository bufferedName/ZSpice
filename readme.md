# ZSpice Verilog Synthesizer

## 基础功能

本项目可以将Verilog代码（RTL级）转为晶体管级spice子电路网表，支持自定义工艺库、自定义逻辑门子电路网表、自定义晶体管参数、Verilog模块引用spice网表、生成Transient Analysis脚本等功能，本程序主要针对Synopsys HSpice开发。

## 运行示例

### 示例文件

在项目目录下，有如下示例文件：

```
./examples/
├── adders.v
├── subckt.sp
└── top.v
```

`adders.v`定义了半加器模块`hadd`和1位全加器模块`add1`，其中半加器模块`hadd`被编译指令对``` `celldefine```和``` `endcelldefine```标记为cell模块：

```verilog
//adders.v
module add1 (input a,
             input b,
             input cin,
             output sum,
             output cout);
    wire s,c1,c2;
    hadd hadd1(.a(a),.b(b),.s(s),.c(c1));
    hadd hadd2(.a(s),.b(cin),.s(sum),.c(c2));
    assign cout = c1 | c2;
endmodule
    
`celldefine
module hadd(input a,input b,output s,output c);
    assign s = a ^ b;
    assign c = a & b;
endmodule
`endcelldefine
```
`subckt.sp`定义了上文`hadd`模块的子电路，由于此模块被标记为cell模块，在综合时会综合为sp网表文件中的同名子电路：

```sp
*subckt.sp
.SUBCKT hadd a b s c
Mp1 buf1 a VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf b buf1 buf1 PMOS_3P3 L=LP W=2*WP
Mn1 out_buf a GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf b GND GND NMOS_3P3 L=LN W=WN
XAND a b c AND
Mp3 buf out_buf VDD VDD PMOS_3P3 L=LP W=2*WP
Mp4 s c buf buf PMOS_3P3 L=LP W=2*WP
Mn3 s out_buf GND GND NMOS_3P3 L=LN W=WN
Mn4 s c GND GND NMOS_3P3 L=LN W=WN
.ENDS hadd
```

`top.v`定义了top_module，功能为4位级联加法器，示例化了4个1位加法器：

```verilog
module top_module(input [3:0] a,b,
                  input cin,
                  output[3:0] sum,
                  output cout);
    wire [3:0]carry_out,carry_in;
    assign cout          = carry_out[3];
    assign carry_in[0]   = cin;
    assign carry_in[3:1] = carry_out[2:0];
    add1 add[3:0](.a(a),.b(b),.cin(carry_in),.cout(carry_out),.sum(sum));
endmodule
```

### 综合结果

在命令行中运行

```bash
$ perl ./src/main.pl ./examples --top top.v -o top.sp --process sm046005-1j.hspice --voltage 3.3 --model SC -t --timescale us --tbStep 0.01 --tbPulse 5 --capacitorLoad 1pF --WP 2u
```

`./src/main.pl`为主程序，
`./examples`指定输入目录为`./examples`，
`--top top.v`指定top_module所在的文件为`top.v`（若无此参数则会自动选取输入文件夹内唯一的.v文件或名字带有top的.v文件），会自动指定此文件内名字内带有top的模块作为顶层模块，
`--process sm046005-1j.hspice`指定工艺库为`sm046005-1j.hspice`（如无指定则默认sm046005-1j.hspice），
`--voltage 3.3`指定$V_{DD}=3.3V$（如无指定则默认$V_{DD}=3.3V$），
`--model SC`指定门模块模型为`SC`（静态互补）（如无指定则默认SC），
`-t`指定需要生成瞬态分析的激励源，
`--timescale us`指定瞬态分析参数的时间单位为$\mu s$（如无指定默认为$ns$），
`--tbStep 0.01`指定瞬态分析最大步长为$0.01\mu s$（如无指定默认为$0.01ns$），
`--tbPulse 5`指定瞬态分析激励源最小脉宽为$5\mu s$（如无指定默认为$10ns$），
`--capacitorLoad 1pF`指定输出负载电容为$1pF$（如无指定默认为$0.01pF$），
`--WP 2u`指定全局PMOS单位宽度为$2\mu m$（如无指定默认为$3.5\mu m$）

程序会在输入目录下的`output`文件夹中生成带有激励源的网表文件，激励源会对所有的输入情况进行激励。上述脚本会输出`./examples/output/top.sp`:

```spice
.LIB sm046005-1j.hspice typical
.OPTION POST
.PARAM WP=2u WN=1u LN=0.35u LP=0.35u


.GLOBAL VDD GND
VDD VDD GND 3.3

.SUBCKT AND in1 in2 out
.LIB sm046005-1j.hspice typical
Mp1 out_buf in1 VDD VDD PMOS_3P3 L=LP W=WP
Mp2 out_buf in2 VDD VDD PMOS_3P3 L=LP W=WP
Mn1 out_buf in1 buf buf NMOS_3P3 L=LN W=2*WN
Mn2 buf in2 GND GND NMOS_3P3 L=LN W=2*WN
XINV GND out_buf out INV
.ENDS AND

.SUBCKT XOR in1 in2 out
.LIB sm046005-1j.hspice typical
XINV_1 GND in1 in1_n INV
XINV_2 GND in2 in2_n INV
Mp1 buf1 in1 VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out in2_n buf1 buf1 PMOS_3P3 L=LP W=2*WP
Mp3 buf2 in1_n VDD VDD PMOS_3P3 L=LP W=2*WP
Mp4 out in2 buf2 buf2 PMOS_3P3 L=LP W=2*WP
Mn1 out in1 buf3 buf3 NMOS_3P3 L=LN W=2*WN
Mn2 out in2_n buf3 buf3 NMOS_3P3 L=LN W=2*WN
Mn3 buf3 in1_n GND GND NMOS_3P3 L=LN W=2*WN
Mn4 buf3 in2 GND GND NMOS_3P3 L=LN W=2*WN
.ENDS XOR

.SUBCKT MUX in1 in2 sel out
.LIB sm046005-1j.hspice typical
XINV GND sel nsel INV
Mp1 out1 in1 VDD VDD PMOS_3P3 L=LP W=WP
Mp2 out1 sel VDD VDD PMOS_3P3 L=LP W=WP
Mn1 out1 in1 buf1 buf1 NMOS_3P3 L=LN W=WN
Mn2 buf1 sel GND GND NMOS_3P3 L=LN W=WN
Mp3 out2 in2 VDD VDD PMOS_3P3 L=LP W=WP
Mp4 out2 nsel VDD VDD PMOS_3P3 L=LP W=WP
Mn3 out2 in2 buf2 buf2 NMOS_3P3 L=LN W=WN
Mn4 buf2 nsel GND GND NMOS_3P3 L=LN W=WN
Mp5 out out1 VDD VDD PMOS_3P3 L=LP W=WP
Mp6 out out2 VDD VDD PMOS_3P3 L=LP W=WP
Mn5 out out1 buf buf NMOS_3P3 L=LN W=WN
Mn6 buf out2 GND GND NMOS_3P3 L=LN W=WN
.ENDS MUX


.SUBCKT INV nc in out
.LIB sm046005-1j.hspice typical
Mp out in VDD VDD PMOS_3P3 L=LP W=WP
Mn out in GND GND NMOS_3P3 L=LN W=WN
.ENDS INV

.SUBCKT OR in1 in2 out
.LIB sm046005-1j.hspice typical
Mp1 buf in1 VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf in2 buf buf PMOS_3P3 L=LP W=2*WP
Mn1 out_buf in1 GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf in2 GND GND NMOS_3P3 L=LN W=WN
XINV GND out_buf out INV
.ENDS OR

.SUBCKT hadd a b s c
.LIB sm046005-1j.hspice typical
Mp1 buf1 a VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf b buf1 buf1 PMOS_3P3 L=LP W=2*WP
Mn1 out_buf a GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf b GND GND NMOS_3P3 L=LN W=WN
XAND a b c AND
Mp3 buf out_buf VDD VDD PMOS_3P3 L=LP W=2*WP
Mp4 s c buf buf PMOS_3P3 L=LP W=2*WP
Mn3 s out_buf GND GND NMOS_3P3 L=LN W=WN
Mn4 s c GND GND NMOS_3P3 L=LN W=WN
.ENDS hadd

.SUBCKT top_module a_0 b_0 a_1 b_1 a_2 b_2 a_3 b_3 cin sum_0 sum_1 sum_2 sum_3 cout
.LIB sm046005-1j.hspice typical
Rshort_cout cout carry_out_3 0
Rshort_carry_in_0 carry_in_0 cin 0
Rshort_carry_in_1 carry_in_1 carry_out_0 0
Rshort_carry_in_2 carry_in_2 carry_out_1 0
Rshort_carry_in_3 carry_in_3 carry_out_2 0
Xadd_01000 a_0 b_0 carry_in_0 sum_0 carry_out_0 add1
Xadd_11001 a_1 b_1 carry_in_1 sum_1 carry_out_1 add1
Xadd_21002 a_2 b_2 carry_in_2 sum_2 carry_out_2 add1
Xadd_31003 a_3 b_3 carry_in_3 sum_3 carry_out_3 add1
.ENDS top_module

.SUBCKT add1 a b cin sum cout
.LIB sm046005-1j.hspice typical
XOR1004 c1 c2 cout OR
Xhadd11005 a b s c1 hadd
Xhadd21006 s cin sum c2 hadd
.ENDS add1



X_TOP a_0 b_0 a_1 b_1 a_2 b_2 a_3 b_3 cin sum_0 sum_1 sum_2 sum_3 cout top_module
C_sum_0 sum_0 GND 1pF
C_sum_1 sum_1 GND 1pF
C_sum_2 sum_2 GND 1pF
C_sum_3 sum_3 GND 1pF
C_cout cout GND 1pF


V_a_0 a_0 GND PULSE(0V 3.3V 5us 0us 0us 5us 10us)
V_b_0 b_0 GND PULSE(0V 3.3V 10us 0us 0us 10us 20us)
V_a_1 a_1 GND PULSE(0V 3.3V 20us 0us 0us 20us 40us)
V_b_1 b_1 GND PULSE(0V 3.3V 40us 0us 0us 40us 80us)
V_a_2 a_2 GND PULSE(0V 3.3V 80us 0us 0us 80us 160us)
V_b_2 b_2 GND PULSE(0V 3.3V 160us 0us 0us 160us 320us)
V_a_3 a_3 GND PULSE(0V 3.3V 320us 0us 0us 320us 640us)
V_b_3 b_3 GND PULSE(0V 3.3V 640us 0us 0us 640us 1280us)
V_cin cin GND PULSE(0V 3.3V 1280us 0us 0us 1280us 2560us)


.TRAN 0.01us 2560us

.END
```

使用HSpice对`top.sp`进行仿真后，即有如下波形：
![png](./examples/output/example_wave.png)

## 环境要求

### 运行环境要求

#### `perl` 

Linux自带，Windows可以安装Strawberry Perl

#### `cpan` 

Linux自带，Windows可以安装Strawberry Perl里面自带

#### `Log::Dispatch` 

apt包管理器系统运行

```bash
$ sudo apt install liblog-dispatch-perl
```

Windows在命令行内运行

```powershell
> cpan Log::Dispatch
```

### 开发环境要求

建议在WSL Linux下开发，Perl的Language Server目前只能在Linux下运行，HSpice大家基本都装在Windows里面（如果装在Linux内当我没说），WSL可以允许Linux系统操作Windows系统内的文件，比VMWare的挂载共享文件夹方便多了。

#### `WSL+Ubuntu`（*可选）

用于跨平台开发与调试

#### `vscode`（*可选）

用于跨平台开发与调试

#### `wget` `ca-certificates` `build-essential` 

必要的编译工具和下载工具，apt包管理器系统运行
```bash
$ sudo apt install wget ca-certificates build-essential
```

#### `libanyevent-perl` `libio-aio-perl` `Perl::LanguageServer` （*可选）

用于VSCode调试，apt包管理器系统运行
```bash
$ sudo apt install libanyevent-perl libio-aio-perl && sudo cpan Perl::LanguageServer
```

#### `graphviz` `libexpat1-dev` `libx11-dev` `perl-tk` （*可选）

用于数据结构可视化，apt包管理器系统运行
```bash
$ sudo install graphviz perl-tk
```
