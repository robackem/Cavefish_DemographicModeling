#!/bin/bash -l
#SBATCH --time=120:00:00
#SBATCH --ntasks=8
#SBATCH --mem=24g
#SBATCH --tmp=100g


module load parallel

# Set paths
SFS_SCRIPT="/home/mcgaughs/robac028/CabMoro_PopGen/2D-SFS/Make_2DSFS.py"
VCF="/home/mcgaughs/robac028/CabMoro_PopGen/vcf_manip/CabMoroProject_ALLpopulations_norep_noindel_noallhet.vcf.gz"

POPS=(CMsurface CMeyed CMcave)

for ((i=0; i<${#POPS[@]}; i++)); do
    for ((j=i+1; j<${#POPS[@]}; j++)); do
        echo "python ${SFS_SCRIPT} ${VCF} ${POPS[$i]} ${POPS[$j]} > ${POPS[$i]}_${POPS[$j]}_2DSFS.sfs"
    done
done | parallel

