
package LetterStats;

use strict;

sub new {
    my $class = shift;

    my $self = {
        patterns=> {},
        };
    bless $self, $class;
    $self;
}

sub patterns { return $_[0]->{patterns}; }
#sub positions { return $_[0]->{positions}; }

sub merge {
my ($this, $that) = @_;
    while ( my ($pattern, $value) = each(%{$that->patterns()}) )
    {
        $this->inc_pattern( $pattern, $value->{positions} );
    }
}

sub inc_pattern {
my ($this, $pattern,$positions) = @_;
    my $blob = $this->{patterns}->{$pattern};
    $this->{patterns}->{$pattern} = $blob = 
        {
            pattern=>$pattern,
            total => 0,
            positions => [0,0,0,0,0],

        } unless $blob;

    foreach my $pos (0 .. scalar(@$positions)-1)
    {
        $blob->{total} += $positions->[$pos];
        $blob->{positions}->[$pos] += $positions->[$pos];
    }
};

sub report {
    my ($this,$options) = @_;
    my $patRef = $this->patterns();
    foreach my $key ( 
        sort { $patRef->{$b}->{total} <=> $patRef->{$a}->{total} }
        keys %$patRef )
    {

        next if $patRef->{$key}->{total} < $options->{min};
        print "$key: total $patRef->{$key}->{total}: word position [",
            join( ',', @{$patRef->{$key}->{positions}} ),
            "]",
            "\n"
            ;
    }
}

1;
