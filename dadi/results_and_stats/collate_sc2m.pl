#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use Getopt::Long;
use Cwd 'abs_path';

# ---------------------------
# Parse arguments
# ---------------------------
my ($in_dir, $out_dir);
GetOptions(
    'i|input=s'  => \$in_dir,
    'o|output=s' => \$out_dir,
);

# Support positional if flags not used
if (!defined $in_dir || !defined $out_dir) {
    ($in_dir, $out_dir) = @ARGV if @ARGV == 2;
}

die "Usage: $0 -i <input_dir> -o <output_dir>\n"
  . "   or: $0 <input_dir> <output_dir>\n"
  unless defined $in_dir && defined $out_dir;

-d $in_dir  or die "Input directory does not exist: $in_dir\n";
-d $out_dir or die "Output directory does not exist: $out_dir\n";

$in_dir  = abs_path($in_dir);
$out_dir = abs_path($out_dir);

# ---------------------------
# Gather files
# ---------------------------
opendir(my $dh, $in_dir) or die "Cannot open directory $in_dir: $!\n";
my @files = grep { /SC2M\.txt$/ && -f "$in_dir/$_" } readdir($dh);
closedir $dh;

die "No *SC2M.txt files found in $in_dir\n" unless @files;

# ---------------------------
# Prepare output
# ---------------------------
my @cols = (
    'Pop 1','Pop 2','Model',
    'Data Likelihoods','Optimized Likelihoods',
    '4*Na*u*L','Na','N1','N2',
    'm21','m12','mi21','mi12',
    'Ts','Tsc','Ts+Tsc','p'
);

my $pop1_name;
my $pop2_name;

my @rows;

FILE:
for my $fn (@files) {
    my $path = "$in_dir/$fn";
    open my $fh, '<', $path or die "Cannot open $path: $!\n";

    my %v = map { $_ => 'NA' } @cols;  # default NA
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line =~ /^#/;

        # Extractors
        $v{'Pop 1'}                = $1 if $line =~ /^#Pop 1:\s*(.+)\s*$/;
        $v{'Pop 2'}                = $1 if $line =~ /^#Pop 2:\s*(.+)\s*$/;
        $v{'Model'}                = $1 if $line =~ /^#Model:\s*(.+)\s*$/;
        $v{'Data Likelihoods'}     = $1 if $line =~ /^#Data Likelihoods:\s*([^\s]+)\s*$/;
        $v{'Optimized Likelihoods'}= $1 if $line =~ /^#Optimized Likelihoods:\s*([^\s]+)\s*$/;
        $v{'4*Na*u*L'}             = $1 if $line =~ /^#4\*Na\*u\*L:\s*([^\s]+)\s*$/;
        $v{'Na'}                   = $1 if $line =~ /^#Na:\s*([^\s]+)\s*$/;
        $v{'N1'}                   = $1 if $line =~ /^#N1:\s*([^\s]+)\s*$/;
        $v{'N2'}                   = $1 if $line =~ /^#N2:\s*([^\s]+)\s*$/;
        $v{'m21'}                  = $1 if $line =~ /^#m21:\s*([^\s]+)\s*$/;
        $v{'m12'}                  = $1 if $line =~ /^#m12:\s*([^\s]+)\s*$/;
        $v{'mi21'}                 = $1 if $line =~ /^#mi21:\s*([^\s]+)\s*$/;
        $v{'mi12'}                 = $1 if $line =~ /^#mi12:\s*([^\s]+)\s*$/;
        $v{'Ts'}                   = $1 if $line =~ /^#Ts:\s*([^\s]+)\s*$/;
        $v{'Tsc'}                  = $1 if $line =~ /^#Tsc:\s*([^\s]+)\s*$/;
        $v{'p'}                    = $1 if $line =~ /^#p:\s*([^\s]+)\s*$/;
    }
    close $fh;

    # Compute Ts+Tsc if both numeric
    my ($ts, $tsc) = ($v{'Ts'}, $v{'Tsc'});
    if ($ts ne 'NA' && $tsc ne 'NA' && $ts =~ /^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$/i && $tsc =~ /^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$/i) {
        my $sum = $ts + $tsc;
        $v{'Ts+Tsc'} = $sum;
    } else {
        $v{'Ts+Tsc'} = 'NA';
    }

    # Record Pop names from the first file to build output name
    if (!defined $pop1_name && $v{'Pop 1'} ne 'NA') {
        $pop1_name = $v{'Pop 1'};
    }
    if (!defined $pop2_name && $v{'Pop 2'} ne 'NA') {
        $pop2_name = $v{'Pop 2'};
    }

    # Ensure Model is SC2M (skip otherwise)
    if (defined $v{'Model'} && $v{'Model'} ne 'NA' && $v{'Model'} ne 'SC2M') {
        warn "Skipping $fn (Model is '$v{Model}', not 'SC2M')\n";
        next FILE;
    }

    # Build row in desired column order
    my @row = map { defined $v{$_} ? $v{$_} : 'NA' } @cols;
    push @rows, \@row;
}

die "Could not determine Pop1/Pop2 from files in $in_dir\n"
  unless defined $pop1_name && defined $pop2_name;

# Output filename
(my $p1 = $pop1_name) =~ s/\s+/_/g;
(my $p2 = $pop2_name) =~ s/\s+/_/g;
my $out_file = "$out_dir/$p1-$p2\_SC2M_summary.txt";

open my $out, '>', $out_file or die "Cannot write $out_file: $!\n";
print $out join("\t", @cols), "\n";
for my $r (@rows) {
    print $out join("\t", @$r), "\n";
}
close $out;

print "Wrote summary for ", scalar(@rows), " file(s): $out_file\n";

