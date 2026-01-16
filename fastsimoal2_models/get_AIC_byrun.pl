#!/usr/bin/env perl
use strict;
use warnings;

# Usage:
#   perl make_AIC_by_run.pl > AIC_by_run.txt


my $out_file = shift @ARGV // "AIC_by_run.txt";

# ----------------------------------------------------------------------
# Step 1: Read all .est files and compute k (number of free parameters)
# ----------------------------------------------------------------------

my %k_for;

my @est_files = glob("*.est");
for my $est_file (@est_files) {

    # Extract prefix: everything before ".est"
    (my $prefix = $est_file) =~ s/\.est$// or next;

    open my $efh, "<", $est_file or die "Cannot open $est_file: $!";

    my $k = 0;
    while (my $line = <$efh>) {
        chomp $line;
        # Trim leading/trailing whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        # Skip empty lines
        next if $line eq '';

        # Skip comment/section lines starting with '/' or '['
        next if $line =~ m{^[\/\[]};

        # Everything else is counted as a parameter line
        $k++;
    }
    close $efh;

    $k_for{$prefix} = $k;
}

# ----------------------------------------------------------------------
# DEBUG BLOCK: Uncomment to print prefix and k to STDOUT
# ----------------------------------------------------------------------
#  foreach my $p (sort keys %k_for) {
#      print "$p\t$k_for{$p}\n";
#  }
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Step 2: Read all *_bestLhoodsParams.txt files and compute AIC per run
# ----------------------------------------------------------------------


my $log10e = 1 / log(10);

# $aic{run_label}{prefix} = AIC value
my %aic;
my %seen_model;   # prefixes that actually have bestLhoods data

my @lh_files = glob("*_bestLhoodsParams.txt");

for my $file (@lh_files) {

    # Extract prefix: everything before "_bestLhoodsParams.txt"
    (my $prefix = $file) =~ s/_bestLhoodsParams\.txt$// or next;

    # Need k for this prefix
    unless (exists $k_for{$prefix}) {
        warn "Skipping $file: no .est-derived k for prefix '$prefix'\n";
        next;
    }
    my $k = $k_for{$prefix};

    open my $fh, "<", $file or die "Cannot open $file: $!";

    # Read header and find Run and MaxEstLhood columns
    my $header = <$fh>;
    chomp $header;
    my @cols = split(/\s+/, $header);

    my %idx;
    for my $i (0 .. $#cols) {
        $idx{$cols[$i]} = $i;
    }

    die "Column 'Run' not found in $file\n"         unless exists $idx{'Run'};
    die "Column 'MaxEstLhood' not found in $file\n" unless exists $idx{'MaxEstLhood'};

    while (my $line = <$fh>) {
        next if $line =~ /^\s*$/;    # skip empty lines
        chomp $line;
        my @f = split(/\s+/, $line);

        my $run = $f[$idx{'Run'}];        # e.g., "run1"
        my $ll  = $f[$idx{'MaxEstLhood'}];

        next unless defined $run && defined $ll && $run ne '';

        # AIC = 2k - 2 * (MaxEstLhood / log10(e))
        my $aic_val = 2 * $k - 2 * ($ll / $log10e);

        $aic{$run}{$prefix} = $aic_val;
        $seen_model{$prefix} = 1;
    }
    close $fh;
}

# ----------------------------------------------------------------------
# Step 3: Output table: rows = runs, columns = model prefixes, values = AIC
# ----------------------------------------------------------------------

open my $out, ">", $out_file or die "Cannot write to $out_file: $!";

# Columns: Run + sorted model prefixes actually seen in bestLhood files
my @models = sort keys %seen_model;
print $out join("\t", "Run", @models), "\n";

# Sort runs by numeric part (run1, run2, ..., run100)
my @runs = sort {
    ($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0]
} keys %aic;

for my $run (@runs) {
    my @vals;
    for my $model (@models) {
        if (exists $aic{$run}{$model}) {
            push @vals, $aic{$run}{$model};
        } else {
            push @vals, "NA";
        }
    }
    print $out join("\t", $run, @vals), "\n";
}

close $out;

