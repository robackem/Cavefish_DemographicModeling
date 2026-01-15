#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

# ===== Population ↔ index and sample sizes =====
my %pop2index = (
    'CMC' => 0, 'CMcave'    => 0,
    'CME' => 1, 'CMeyed'    => 1,
    'CMS' => 2, 'CMsurface' => 2,
);
my %pop2n = (
    'CMC' => 38, 'CMcave'    => 38,
    'CME' => 34, 'CMeyed'    => 34,
    'CMS' => 12, 'CMsurface' => 12,
);

# ---- Only look for .sfs ----
my @files = glob("*_2DSFS.sfs");
die "No *_2DSFS.sfs files found in this directory.\n" unless @files;

FILE:
for my $infile (@files) {
    my ($base) = fileparse($infile);
    my ($p1, $p2) = $base =~ /^([^_]+)_([^_]+)_2DSFS\.sfs$/;
    unless (defined $p1 && defined $p2) {
        warn "Skipping $infile (could not parse population names)\n";
        next FILE;
    }

    die "Unknown population '$p1' in $infile\n" unless exists $pop2index{$p1} && exists $pop2n{$p1};
    die "Unknown population '$p2' in $infile\n" unless exists $pop2index{$p2} && exists $pop2n{$p2};

    my $idxX = $pop2index{$p1};   # rows
    my $idxY = $pop2index{$p2};   # columns
    my $nX   = $pop2n{$p1};
    my $nY   = $pop2n{$p2};

    my $rows = $nX + 1;
    my $cols = $nY + 1;
    my $expected = $rows * $cols;

    my $out  = sprintf("jointDAFpop%d_%d.obs", $idxX, $idxY);

    # ---- Read dadi SFS ----
    open my $IN, "<", $infile or die "Cannot open $infile: $!\n";
    my $saw_dims = 0;
    my @nums;
    while (my $line = <$IN>) {
        chomp $line;
        next if $line =~ /^\s*#/;  # comments
        # dims line like "35 39 unfolded" (word optional/case-insensitive)
        if (!$saw_dims && $line =~ /^\s*\d+\s+\d+(?:\s+\w+)?\s*$/i) {
            $saw_dims = 1;
            next;
        }
        next unless $saw_dims;

        # collect any integers on subsequent lines
        while ($line =~ /(\d+)/g) {
            push @nums, $1;
            last if @nums >= $expected;  # stop as soon as we have enough
        }
        last if @nums >= $expected;      # we have our counts vector
    }
    close $IN;

    die "No counts vector found in $infile\n" unless @nums;
    die "Counts too short in $infile: got ".scalar(@nums)." < expected $expected\n" if @nums < $expected;

    # take exactly the first expected numbers (ignore trailing mask etc.)
    my @counts = @nums[0 .. $expected-1];

    # ---- Rebuild matrix in row-major order (Pop1 rows, Pop2 cols) ----
    my @matrix;
    {
        my $k = 0;
        for my $r (0 .. $rows - 1) {
            my @row;
            for my $c (0 .. $cols - 1) {
                $row[$c] = $counts[$k++];
            }
            $matrix[$r] = \@row;
        }
    }

    # ---- Write FSC2 .obs with labels ----
    open my $OUT, ">", $out or die "Cannot write $out: $!\n";
    print $OUT "1 observations\n";
    print $OUT "\t", join("\t", map { "d${idxY}_$_" } 0 .. $nY), "\n";
    for my $i (0 .. $nX) {
        print $OUT "d${idxX}_$i\t", join("\t", @{$matrix[$i]}), "\n";
    }
    close $OUT;

    print "Wrote $out (rows=$p1 idx=$idxX n=$nX; cols=$p2 idx=$idxY n=$nY) from $infile\n";
}

__END__

