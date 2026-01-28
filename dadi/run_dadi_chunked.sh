#!/bin/bash -l
#SBATCH --job-name=dadi_array_chunks
#SBATCH --array=0-749
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=96:00:00
#SBATCH --output=/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/Logs/chunk_%A_%a.out
#SBATCH --error=/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/Logs/chunk_%A_%a.err
#SBATCH --mail-type=NONE
#SBATCH --mail-user=robac028@umn.edu

module load conda
source activate dadi_env

cd /home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/OUTPUT

set -euo pipefail

CHUNK_BASE="/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/Jobs"
CHUNK_DIR="${CHUNK_BASE}/chunks"

# Collect only the new chunk files
mapfile -t CHUNK_FILES < <(ls -1 "${CHUNK_DIR}"/chunk_*.txt 2>/dev/null | sort)

NUM_FILES=${#CHUNK_FILES[@]}
if [[ ${NUM_FILES} -eq 0 ]]; then
  echo "ERROR: No chunk_*.txt files found in ${CHUNK_DIR}"
  exit 1
fi

# Guard against out-of-range array indices
if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]] || [[ ${SLURM_ARRAY_TASK_ID} -ge ${NUM_FILES} ]]; then
  echo "ERROR: SLURM_ARRAY_TASK_ID (${SLURM_ARRAY_TASK_ID:-unset}) is out of range 0..$((NUM_FILES-1))"
  exit 2
fi

CHUNK_FILE=${CHUNK_FILES[$SLURM_ARRAY_TASK_ID]}
echo "[$(date)] Running chunk index ${SLURM_ARRAY_TASK_ID}/${NUM_FILES}: ${CHUNK_FILE}"

# Run each command line in the chunk file (skip blanks/comments defensively)
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line// }" ]] && continue         # skip blank lines
    [[ "${line#"${line%%[![:space:]]*}"}" =~ ^# ]] && continue  # skip comment lines
    echo "[$(date)] Launching: $line"
    bash -c "$line"
done < "$CHUNK_FILE"

echo "[$(date)] Done with: $CHUNK_FILE"
