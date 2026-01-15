#!/usr/bin/env python
"""Parse the VCF with invariant sites, and generate a 2D SFS
We will skip sites that have any missing data in any of the
populations of interest. Takes three arguments:
    1) Gzipped VCF with invariant sites
    2) Population 1 name
    3) Population 2 name
"""

import sys
import gzip
import pprint
import re


# Unpack arguments
try:
    gzvcf = sys.argv[1]
    pop1 = sys.argv[2]
    pop2 = sys.argv[3]
except IndexError:
    print("""Parse the VCF with invariant sites, and generate a 2D SFS
We will skip sites that have any missing data in any of the
populations of interest. Takes three arguments:
    1) Gzipped VCF with invariant sites
    2) Population 1 name
    3) Population 2 name""")
    exit(1)

# Define a population name dictionary to identify samples in VCF
POPNAMES = {
    'CMcave': r'^C[0-9]',
    'CMeyed': r'^E[0-9]',
    'CMsurface': r'^S[0-9]|^Sr[0-9]'
}

# We want to exclude individuals that appear to be of recent
# hybrid origin, or are from potential outgroups we decided not to use
EXCLUDE = ['A_aenus_surface']

# Translate the names from the full name into the VCF name
pop1 = POPNAMES[pop1]
pop2 = POPNAMES[pop2]
# And define the ancestral
ANCESTRAL = ['Nicara_T6903', 'Nicara_T6904']

# Start a counter for the number of sites considered
n_sites = 0

with gzip.open(gzvcf, 'rt') as f:
    for line in f:
        if line.startswith('##'):
            continue
        elif line.startswith('#CHROM'):
            header = line.strip().split()
            # Get the indices of the sample fields we want to process
            pop1_pattern = re.compile(pop1)
            pop1_samples = [i for i, s in enumerate(header) if pop1_pattern.search(s) and s not in EXCLUDE]
            pop2_pattern = re.compile(pop2)
            pop2_samples = [i for i, s in enumerate(header) if pop2_pattern.search(s) and s not in EXCLUDE]
            anc_samples = [header.index(s) for s in ANCESTRAL if s in header]
            # Write some output to stderr
            sys.stderr.write('Pop 1: ' + ','.join([header[i] for i in pop1_samples]) + '\n')
            sys.stderr.write('Pop 2: ' + ','.join([header[i] for i in pop2_samples]) + '\n')
            sys.stderr.write('Anc: ' + ','.join(ANCESTRAL) + '\n')
            # How many alleleic states can we identify?
            pop1_n = (2*len(pop1_samples)) + 1
            pop2_n = (2*len(pop2_samples)) + 1
            # Then, start an empty matrix to hold the SFS data. Rows will be
            # pop1 samples, and columns will be pop2 samples.
            sfs = []
            for i in range(0, pop1_n):
                tmp = []
                for j in range(0, pop2_n):
                    tmp.append(0)
                sfs.append(tmp)
        else:
            tmp = line.strip().split()
            # Check ref and alt. If there are length polymorphisms, we want to
            # avoid those.
            ref = tmp[3]
            alt = tmp[4]
            if len(ref) != 1 or len(alt) != 1:
                continue
            # Now, we are in the data rows. First, subset the genotypes
            pop1_geno = [tmp[g].split(':')[0] for g in pop1_samples]
            pop2_geno = [tmp[g].split(':')[0] for g in pop2_samples]
            anc_genos = [tmp[i].split(':')[0] for i in anc_samples]
            # Skip site if any ancestral genotype is missing or heterozygous
            if any(g not in ['0/0', '1/1'] for g in anc_genos):
                continue
            # Ensure all ancestral samples agree
            if len(set(anc_genos)) != 1:
                continue
            # Skip site if any population genotype is missing
            if './.' in pop1_geno or './.' in pop2_geno:
                continue
            # Ancestral state is shared and unambiguous
            anc_geno = anc_genos[0]
            # Next, we count up the derived alleles
            if anc_geno == '0/0':
                derived = '1'
                anc = '0'
            elif anc_geno == '1/1':
                derived = '0'
                anc = '1'
            pop1_der = 0
            pop2_der = 0
            for call in pop1_geno:
                if call == derived + '/' + derived:
                    pop1_der += 2
                elif call == derived + '/' + anc or call == anc + '/' + derived:
                    pop1_der += 1
                else:
                    pop1_der += 0
            for call in pop2_geno:
                if call == derived + '/' + derived:
                    pop2_der += 2
                elif call == derived + '/' + anc or call == anc + '/' + derived:
                    pop2_der += 1
                else:
                    pop2_der += 0
            # Then, put them into the matrix
            sfs[pop1_der][pop2_der] += 1
            n_sites += 1

# Unpack the SFS into the vector expected by dadi, and build the mask
sfs_vec = []
mask = []
for row in sfs:
    for col in row:
        sfs_vec.append(str(col))
        mask.append('0')

# Then, we want to mask the fixed sites
mask[0] = '1'
mask[-1] = '1'

# Print the SFS. We can include comment lines.
print('#Pop 1: ' + sys.argv[2])
print('#Pop 1 Samples: ' + ','.join([header[i] for i in pop1_samples]))
print('#Pop 2: ' + sys.argv[3])
print('#Pop 2 Samples: ' + ','.join([header[i] for i in pop2_samples]))
print('#Ancestral: ' + ','.join(ANCESTRAL))
print('#N sites: ' + str(n_sites))
print(pop1_n, pop2_n, 'unfolded')
print(' '.join(sfs_vec))
print(' '.join(mask))
