
use strict;
use File::Copy;
use Getopt::Long;
use Data::Dumper;

use constant True => 1;
use constant False => 0;

my $config = process_cmdline();
print Data::Dumper->Dump( [$config], ["config"] ) if $config->{show_config};
usage( "" ) if $config->{help};

my $words = input_source($config->{source});

add_words($config->{add}, $words, $config->{source}) if @{$config->{add}};
remove_words( $config->{remove}, $words, $config->{source}) if @{$config->{remove}};
print "Word list count:  ", scalar(keys %$words),"\n";

search( $config->{lookup}, $words, True ) if @{$config->{lookup}};
frequency( $config->{frequency}, $words ) if @{$config->{frequency}};
exit;

sub frequency {
my ($patterns, $words_hr) = @_;
    
    my %letters;
    foreach my $pattern ( @$patterns )
    {
        my ($filter) = $pattern =~ /F(.+)/;
        $pattern =~ s/F$filter// if $filter;
        $filter = "P1.P2.P3.P4.P5." unless $filter;
        #print "Freq filter $filter\n";
        my @posFilters;
        foreach my $pos ( 1 .. 5 )
        {
            my ($pf) = $filter =~ /P$pos([^P]+)/;
            $pf =~ s/V/[aeiouy]/g if $pf;
            $pf =~ s/C/[^aeiouy]/g if $pf;
            $posFilters[$pos-1] = $pf;
        }

        my $wordlist = search( [$pattern], $words_hr, False );
        foreach my $word ( @$wordlist )
        {
            #print $word,"\n";
            my @letters = split "",$word;

            my $index = -1;
            foreach my $letter ( @letters )
            {
                ++$index;
                my $testAgainst = $posFilters[$index];
                next unless $testAgainst;
                next unless $letter =~ /($testAgainst)/;
                #my ($matched) = $letter =~ /($testAgainst)/;
                #next unless $matched;

                #print "$word .. $letter counted at postion ", $index+1,"\n";
                my $blob = $letters{ $letter };
                $letters{ $letter } = $blob = {
                    letter => $letter,
                    total => 0,
                    frequency => [0,0,0,0,0],
                    } unless $blob;
                ++$blob->{total};
                ++$blob->{frequency}->[$index];
            }
        }
    }
    report_frequency( \%letters );
    \%letters;
}

sub search {
my ($tofind_ar, $words_hr, $display) = @_;
    my @results;
    foreach my $pattern (@$tofind_ar)
    {
        my $and = $pattern =~ s/A/ /g;
        if ( $and )
        {
            print "And $pattern\n";
            my @subpats = split /\s/,$pattern;
            my $words = $words_hr;
            foreach my $next ( @subpats )
            {
                print $next,"\n";
                my $r1 = search( [$next], $words, False );
                $words =  { map { $_ => 1 } @{$r1} };
                #print Data::Dumper->Dump( [sort keys %$words] );
            }
            push @results,keys %$words;
            next;
        }
        $pattern =~ s/V/[aeiouy]/g;
        $pattern =~ s/C/[^aeiouy]/g;
        my @found = grep{ /$pattern/; } sort keys %$words_hr;
        print "Found ",scalar(@found), " matches to pattern $pattern\n";
        push @results, @found;
    }
    print(join("\n", sort @results),"\n") if $display;
    \@results;
}

sub add_words {
my ($source_ar, $dest_hr, $outputfile) = @_;

    my $modified = False;
    foreach my $toadd ( @$source_ar )
    {
        if  (-f $toadd)
        {
            my $addList = words_from_file($toadd);
            my @toadd = grep { ! $dest_hr->{$_} } @$addList;
            add_words( \@toadd, $dest_hr, $outputfile );
            next;
        }

        print "adding '$toadd'";
        print(":ignored, word length must be 5\n"),next unless length($toadd)==5;
        print(":ignored, already present\n" ),next if $dest_hr->{$toadd};
        print("\n");
        $modified = True;
        $dest_hr->{$toadd} = 1;
    }
    write_source( $outputfile, $dest_hr ) if $modified;
}

sub remove_words {
my ( $source_ar, $dest_hr, $outputfile ) = @_;

    my $modified = False;
    foreach my $toDelete ( @$source_ar )
    {
        if  (-f $toDelete) 
        {
            my $removeList = words_from_file($toDelete);
            #print Data::Dumper->Dump( [$removeList] );
            remove_words( $removeList, $dest_hr, $outputfile );
            next;
        }

        next unless delete $dest_hr->{$toDelete};
        print "removed '$toDelete\n'";
        $modified = True;
    }
    write_source( $outputfile, $dest_hr ) if $modified;
}

sub words_from_file {
my ($filename) = @_;

    my @list;
    open IN,"$filename";
    while ( <IN> )
    {
        #print;
        chomp;
        s/[\"|\.|\,|\-|;|_]//g; 
        push @list, 
            grep { length == 5 && !/[[:upper:]]/ && !/\W/ }
            split /\s/
            ;
    }

    if ( @list )
    {   # remove dups
        my %hashit = map { $_ => 1 } @list;
        @list = sort keys %hashit;
    }
    \@list;
}

sub report_frequency {
my ($letterStats) = @_;

    #print Data::Dumper->Dump( [$letterStats] );
    foreach my $key ( 
        sort 
        { 
            my $result = $letterStats->{$b}->{total} <=> $letterStats->{$a}->{total};
            $result = $letterStats->{$b}->{letter} cmp $letterStats->{$a}->{letter} if $result == 0;
            $result;
        }
        keys %$letterStats )
    {
        my $counts = $letterStats->{$key};
        my $freq = $counts->{frequency};
        print "'$counts->{letter}': total $counts->{total} ",
            "Frequency [", 
            join(",", @{$counts->{frequency}}), 
            "]",
            "\n";
    }
}

sub process_words {
my ($hrWords ) = @_;

    my %letters;
    foreach my $word (keys %$hrWords)
    {
        my %wordStats;
        #print $word,"\n";
        my @letters = split "",$word;
        my $index = -1;
        while ( @letters )
        {
            #my $index = @letters;
            ++$index;

            my $letter = shift @letters;
            ++$letters{total};
            #print "$index, $letter\n";

            my $blob = $letters{ $letter };
            $letters{ $letter } = $blob = {
                letter => $letter,
                total => 0,
                positions => [0,0,0,0,0],
                frequency => [0,0,0,0,0],
                } unless $blob;
            ++$blob->{total};
            ++$blob->{positions}->[$index];

            ++$wordStats{$letter};
        }

        #print Data::Dumper->Dump([%wordStats]);
        foreach my $letter (keys %wordStats)
        {
            my $letterFreq = $letters{$letter}->{frequency};
            die unless $letterFreq;

            #print "$letter .. $occurances\n";
            ++$letterFreq->[$wordStats{$letter}-1];
        }
    }
    #print Data::Dumper->Dump( [%letters] );
    \%letters;
}

sub input_source {
my ($input) = @_;
    die "Source $input not found or empty\n" unless -f $input and -s $input;
    my %wordHash = map { $_ => 1 } @{words_from_file($input)};
    #print Data::Dumper->Dump( [%wordHash] );
    \%wordHash;
}

sub write_source {
my ($destfile, $words_hr) = @_;

    print "Rewriting '$destfile', backup under $destfile.bak\n";
    copy( $destfile, "$destfile.bak");
    open OUT,">$destfile";
    print OUT join("\n", sort keys %$words_hr),"\n";
    close OUT;

}

sub usage {
    print join( ',', @_),"\n";
    print <<eom;
Usage: [perl] wordStats.pl [options]
    options 
        -c, --config: show configuration
        -s,--source filename: use filename as input, default WordList.txt
        -a,--add: add word to source filename, can be specified multiple times
            If 'word' is found to be a local filename that file will be scanned for candidate words to add
        -r, --remove: inverse of --add
        -l,--lookup: find/displays regex pattern, multiples allow, examples below
        -f,--frequency: displays counts of matches to pattern
        -h, --help: show usage (this)


        pattern matching notes:
            ^ \$ anchors matches to begining/end of word
            quotes optional unless pattern contains a ^ (cmd line strips out)
            words are all lower case, uppercase used to specify meta patterns
            V expands to any vowel
            C expands to any consonant 
            A ands patterns results (i.e. returns intersection)

            examples:
                -l . : matchs all
                -l ab : finds all word containing ab
                -l "^ab" : finds all word starting with ab (quotes required)
                -l .ab.. : finds ab starting in the 2 position
                -l .[ie]... : all words with i or e in the second positions 
                -l y\$ : all words ending with y
                -l "V{2}" : all words with sequence of 2 or more vowels
                -l [i]A[t]A^..[^i][^t]: returns words which
                    contains an 'i'
                    and contains a 't'
                    and the third position is not an 'i' and the fourth position in not a 't'

            F specifes a letter frequency filter, following a matching pattern
                -f option only
                defaults to any char in each position
                if specified the filter for each desired position must be specified
                template: FP1filterP2filter...

            examples
                -f ".FP1V" : letter frequency count of vowels in first position in all words
                -f "y$\FP4.": letter frequency count of any char preceding a final 'y'

                    
eom

    die("\n");
}

sub process_cmdline {
my %config = (
    source => "WordList.txt",
    show_config => False,
    add => [],
    remove => [],
    frequency => [],
    lookup => [],
    help => False,
    );

    GetOptions(
        "add=s@"    => \$config{add},
        "remove=s@" => \$config{remove},
        "lookup=s@" => \$config{lookup},
        "frequency=s@"  => \$config{frequency},
        "config"    => \$config{show_config},
        "help"      => \$config{help},
        "source=s"  => \$config{source},
    );
    \%config;
}

