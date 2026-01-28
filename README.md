# **Demographic Modeling**

Understanding complex demographic histories in _Astyanax mexicanus_ cavefish with coalescent modeling

-------------------------------------------------------------------------------------------------------------------
## Pipeline for fastsimcoal2  

### Generate joint site frequency spectra (SFS) of derived alleles from population genomic data

**Necessary input:**  
VCF file containing SNPs and invariant sites genome-wide for populations of interest and at least one individual from an outgroup species (needed to identify the ancestral state for each position in the genome). This VCF should be filtered down, removing regions containing indels and repetitive regions. We will require full genotype coverage in each population being compared when generating the SFS, so this filtering does not need to be done in advance. 

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

The output of this step is a SFS in a one line format, followed by a second line of 0 and 1 values indicating whether the site should be masked from further analyses (1 = masked, 0 = no mask, _note masking can be changed within the script_). This format can be used for analysis with dadi. For analysis with fastsimcoal2 we convert this oneline format to a matrix using `SFS_oneline2matrix.pl` to produce `*.obs` files for each population pair.

For conversion to matrix format compatible with fastsimcoal2 you will need to specify a population index (n populations numbered 0 to n-1 consistent through all analyses, _see fsc2 documentation_) and the <ins>haploid</ins> sample size of each population from the VCF in `SFS_oneline2matrix.pl` at line 6:

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

### Maximum likelihood demographic modeling

**All coalescent topologies modeled and key for populations, events, and gene flow regimes:**
![](/fastsimoal2_models/CoalescentTopologies.png)

**Necessary input:** 
```
*_jointDAFpop1_0.obs
*_jointDAFpop2_0.obs
*_jointDAFpop2_1.obs
*.tpl
*.est
```  

`*.obs` files are produced in the previous step: _Generate joint site frequency spectra (SFS) of derived alleles from population genomic data_. See examples: `/fastsimcoal2_models/CabMoro_jointDAFpop*.obs`

Each demographic model (i.e., each combination of coalescent topology, historical events, and applicable gene flow regime) is specified in the `*.tpl` file.   

The multinomial likelihood is estimated by approximating the observed SFS through coalescent simulations given a set of parameter values. The maximum likelihood estimate is achieved through an expectation conditional maximization algorithm that iteratively finds parameters maximizing the likelihood of the given model. For all model parameters, the initial value is randomly sampled from a wide search range of potential values, given in the `*.est` file. 

**Running fastsimcoal2 and analyzing output**  
`launch_fsc_runs.sh` --> this single script allows you to launch as many interations of fsc as needed (set to 100 by default), and specify all fsc parameters (just change the values on the indicated lines). You can also specify all information needed by your HPC scheduler (runtime, memory, etc.) for your fsc runs. The script is currently set up to work with the SLURM scheduler. Run this script in a directory with the 5 necessary input files for a demographic model and it will do the rest.  

Additionally, this script can also be used to collate the data from all 100 independent fsc runs by changing the commented line at line 16:
``` 
# if doComputations==1, the script will submit runs of fsc to the HPC scheduler
# if doComputations==0, the script will just collect the results previously generated from past runs
# so uncomment the line you need

#doComputations=0
doComputations=1
```
This will produce a file `*_bestLhoodsParams.txt` containing the output for all 100 runs of the model (or however many you ran).  

_Note:_ if submitting runs or collating data for many different demographic models within the same directory, ensure that each demographic model and all input files corresponding to that model have a consistent, unique prefix: e.g., `[prefix].tpl` + `[prefix].est` ... etc. The script will work by prefix to submit 100 runs for each model or collate data from those runs for each model separately based on prefix. 

`get_AIC_byrun.pl` --> calculate AIC from the maximum observed likelihood achieved in each run of fsc for all models tested. The output looks like this:  

```
run#    model-01    model-02    model-03
01        AIC         AIC          AIC
02        AIC         AIC          AIC
``` 
_Note:_ The script is able to intuitively calculate k (the number of free parameters) in each model from the .est file, so be sure to have a copy of the .est file for each model tested in the directory. 

`Akaike_Weights.R` --> convert the AIC values into an Akaike weight for each overall model. The Akaike weight serves as a value that can be directly interpreted as the conditional probability for each model. In other words, the Akaike weight reflects the probability that the given demographic model best replicates the observed SFS among the models tested. 

## Custom Dadi package for cavefish
Coalescent demographic modeling based on derived allele site frequency spectra from whole genome sequencing  
This custom python package is an extension of the work of Tom Kono, _see:_ https://github.com/TomJKono/CaveFish_Demography/wiki

In order to function, the package must remain in this layout:
``` 
cavefish_dadi/
├── Models/
│   ├── __init__.py
│   ├── demo_model.py
│   ├── si.py
│   ├── im.py
│   ├── am.py
│   ├── sc.py
│   ├── im2m.py
│   ├── am2m.py
│   └── sc2m.py
├── Optim/
│   ├── __init__.py
│   └── dadi_custom.py
└── Support/
    ├── __init__.py
    ├── arguments.py
    └── module_test.py
```

The package is initiated by running `SEM_CaveFish_Dadi.py`
```
usage: SEM_CaveFish_Dadi.py [-h] -f SFS -m {SI,SC,AM,IM,SC2M,AM2M,IM2M} -p POP
                            [-o OUT] [-n NITER] [-r REPLICATES] -l LENGTH

optional arguments:
  -h, --help            show this help message and exit
  -f SFS, --sfs SFS     Joint SFS file, in dadi format
  -m {SI,SC,AM,IM,SC2M,AM2M,IM2M}, --model {SI,SC,AM,IM,SC2M,AM2M,IM2M}
                        Specify a model to run. May be specified multiple
                        times, with different models.
  -p POP, --pop POP     Population labels. Must be specified in order that
                        they are listed in dadi SFS file.
  -o OUT, --out OUT     Output prefix for results files. Defaults to
                        CaveFish_Dadi_Out
  -n NITER, --niter NITER
                        Number of iterations for the simulated annealing.
  -r REPLICATES, --replicates REPLICATES
                        Number of replicates to perform for each model.
  -l LENGTH, --length LENGTH
                        Length of the locus. Note that this is the size of
                        region, including invariant sites, that was used to
                        generate the SFS.
```

For running many replicates on a HPC, I recommend first putting together a file of all commands, _see_ `ALL_dadi_commands.txt`. Then you can split that master file into chunks _see_  `chunk_744.txt` and submit the chunks to the scheduler to make best use of available resources with `run_dadi_chunked.sh` 

How to split a master file into manageable chunks:  

Master file (ALL_dadi_commands.txt) has 5250 commands (5250 lines)  
Each of the 7 models has 50 replicates (to derive parameter estimates across many runs)  
So we split the master file into 750 chunks, each containing 1 replicate (1 run of each model)  

```
split -d -a 3 -l 7 ALL_dadi_commands.txt chunk_
```

`-l 7` = 7 lines per chunk  
`-d` = numeric suffixes  
`-a 3` = 3 digits (000 … 749)  
`chunk_` = prefix, so outputs chunk_000, chunk_001, … chunk_749    

Scripts for collating results and calculating stats can be found in `/dadi/results_and_stats/`  

The following table highlights the major differences in package function from previous iterations of the models

| Change Made | Description |
| --- | --- |
| Use of 2 ancestral samples | The code now considers 2+ genotypes when estimating the ancestral allele. Sites are excluded from the 2D SFS if they are heterozygous (i.e., 0/1) in the outgroup or if there was not a consensus between outgroup individuals, given that we cannot determine which allele is the ancestral state at these sites. |
| Removed mask on sites at frequency of 0.5 in both populations  | Prior to generating the SFS we removed sites from the VCF that were heterozygous (i.e., 0/1) in every single individual sampled, as these likely represent paralogous alignment from the ancient teleost genome duplication rather than true heterozygous sequence variants. However, the previous version of the script ALSO masked all sites in the SFS that had a frequency of 0.5 in both populations. I removed the mask over these sites because we already removed these potential paralogous sites, and sites can have a population frequency of 0.5 from other genotype combinations (e.g. if half the individuals are 0/0 and half are 1/1) so these sites could be informative to the demographic model |
| Mutation rate | Updated the mutation rate from 3e-9 to 5.62e-9 per the estimated mutation rate of more closely related fish species (common carp from "Evolution of the germline mutation rate across vertebrates" Bergeron et al 2023 in Nature) |
| Calculation of median total divergence time | For the SC2M model, the 2018 analysis calculates median total divergence time as (medain Ts) + (median Tsc). I changed this to calculate Ts + Tsc in each of the 50 reps individually first, then take median(Ts+Tsc) _Note: SC2M is used as an example here, but this method should be followed for all mean estimates of parameters derived from other parameters in the model (eg., mean x+y or mean z-a)_ |
