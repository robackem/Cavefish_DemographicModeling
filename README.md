# **Demographic Modeling**

Understanding complex demographic histories in _Astyanax mexicanus_ cavefish with coalescent modeling

-------------------------------------------------------------------------------------------------------------------
## Pipeline for fastsimcoal2  

### Generate joint site frequency spectra (SFS) of derived alleles from population genomic data

**Necessary input:** VCF file containing SNPs and invariant sites genome-wide for populations of interest and at least one individual from an outgroup species (needed to identify the ancestral state for each position in the genome). This VCF should be filtered down, removing regions containing indels and repetitive regions. We will require full genotype coverage in each population being compared when generating the SFS, so this filtering does not need to be done in advance. 

To generate all necessary SFS use `Make_2DSFS.py`  
The process is executed using `run2DSFS.sh`  
_Note These scripts are largely flexible, but require a few tweaks to be used in a new context_

`Make_2DSFS.py` line 30: define a dictionary so that the script can identify which samples in the VCF belong to which populations
```
# Define a population name dictionary to identify samples in VCF
POPNAMES = {
    'CMcave': r'^C[0-9]',
    'CMeyed': r'^E[0-9]',
    'CMsurface': r'^S[0-9]|^Sr[0-9]'
```
`Make_2DSFS.py` line 44: define individuals from the ancestral population (outgroup)
```
# And define the ancestral
ANCESTRAL = ['Nicara_T6903', 'Nicara_T6904']
```
`run2DSFS.sh` line 14: define populations to make joint-SFS for (this will fully automate the process and generate a SFS for every pair of populations listed
```
POPS=(CMsurface CMeyed CMcave)
```


The output of this step is a SFS in a one line format, followed by a second line of 0 and 1 values indicating whether the site should be masked from further analyses (1 = masked, 0 = no mask, _note masking can be changed within the script_). This format can be used for analysis with dadi. For analysis with fastsimcoal2 we convert this oneline format to a matrix using `SFS_oneline2matrix.pl`

For conversion to matrix format compatible with fastsimcoal2 you will need to specify a population index (n populations numbered 0-n consistent through all analyses, _see fsc2 documentation_) and the <ins>haploid</ins> sample size of each population from the VCF. 

`SFS_oneline2matrix.pl` line 6:
```
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
```

### Demographic modeling




