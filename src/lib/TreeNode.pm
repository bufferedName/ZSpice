#!/usr/bin/perl -w
use strict;
# use GraphViz;

package TreeNode;

our $tagCount = 10000;

sub new {
    my $class    = shift;
    my $data     = shift;
    my $children = (@_) ? \@_ : [];
    my $tag      = $tagCount;
    $tagCount += 1;
    my $self =
      { data => $data, children => $children, parent => undef, tag => $tag };
    bless $self, $class;
    return $self;
}

sub get_tag{
    $tagCount += 1;
    return $tagCount;
}

our $AUTOLOAD;

sub AUTOLOAD {
    my $self      = shift;
    my $method    = $AUTOLOAD;
    my $className = $AUTOLOAD;
    $className =~ s/::.*//;
    $method    =~ s/.*:://;

    if ( exists $$self{"$method"} ) {    #auto get method and set method
        $self->{"$method"} = shift if (@_);
        return $self->{"$method"};
    }
    else {
        die "Undefined attribute '$method' of Class $className";
    }
}

sub new_child {
    my $self     = shift;
    my $new_node = shift;
    $new_node->parent($self);
    my $children = $self->children();
    push @$children, $new_node;
}

# sub to_graphviz {
#     my $self = shift;
#     my $g    = GraphViz->new();
#     _add_node_edges( $g, $self );
#     $g->as_png('tree.png');
# }

sub has_child {
    my $self = shift;
    return @{ $self->children() };
}

# sub _add_node_edges {
#     my ( $g, $node ) = @_;
#     $g->add_node( $node, label => $node->data() );
#     foreach my $child ( @{ $node->children() } ) {
#         $g->add_edge( $node => $child );
#         _add_node_edges( $g, $child );
#     }
# }

sub DESTROY {
    my $self = shift;
}

1;
