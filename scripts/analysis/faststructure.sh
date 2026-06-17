#!/bin/bash
#SBATCH --partition=guest
#SBATCH --job-name=f4_faststructure_array_K1-10
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=2-00:00:00
#SBATCH --array=1-10
#SBATCH --output=faststructure_K%a.out
#SBATCH --error=faststructure_K%a.err

## record relevant job info
echo "Starting working directory: $(pwd)"
echo "Host name: $(hostname)"
echo "Run date: $(date)"
printf "\n"

# Load module
module purge
module load faststructure/1.0

BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKING_DIR=${BASEDIR}/downsampled_our_data_and_online/final_vcf
OUTDIR=${WORKING_DIR}/faststructure_results

# Input file (without .str extension - fastStructure adds it automatically)
INPUT_FILE=${WORKING_DIR}/combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi_pruned
INPUT_FILE_NOHEADER=${WORKING_DIR}/combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi_pruned_noheader

# Create output directory
mkdir -p ${OUTDIR}
cd ${WORKING_DIR}

# Check if input .str file exists
if [ ! -f "${INPUT_FILE}.str" ]; then
    echo "Error: Input STRUCTURE file not found: ${INPUT_FILE}.str"
    exit 1
fi

# Remove header line if noheader version doesn't exist (only task 1 creates it)
if [ ${SLURM_ARRAY_TASK_ID} -eq 1 ] && [ ! -f "${INPUT_FILE_NOHEADER}.str" ]; then
    echo "Creating version without header..."
    tail -n +2 "${INPUT_FILE}.str" > "${INPUT_FILE_NOHEADER}.str"
    echo "✓ Header removed"
fi

# Wait for file to be created if not task 1
if [ ${SLURM_ARRAY_TASK_ID} -ne 1 ]; then
    while [ ! -f "${INPUT_FILE_NOHEADER}.str" ]; do
        sleep 2
    done
fi

# K value is just the array task ID
K=${SLURM_ARRAY_TASK_ID}

# Create unique seed for each K
SEED=$((29092025 + K))

echo "Running fastStructure for K=${K}, TaskID=${SLURM_ARRAY_TASK_ID}, Seed=${SEED}"
echo "Input file: ${INPUT_FILE_NOHEADER}.str"
echo "Output prefix: ${OUTDIR}/faststructure_K${K}"
printf "\n"

# Run fastStructure (now using noheader version)
/util/opt/anaconda/deployed-conda-envs/packages/faststructure/envs/faststructure-1.0/bin/structure.py \
    -K ${K} \
    --input=${INPUT_FILE_NOHEADER} \
    --output=${OUTDIR}/faststructure_K${K} \
    --format=str \
    --seed=${SEED} \
    --full

if [ $? -ne 0 ]; then
    echo "Error: fastStructure failed for K=${K}"
    exit 1
fi

echo "✓ Finished K=${K}"
echo "  Output files: ${OUTDIR}/faststructure_K${K}.${K}.*"
echo "Completed at: $(date)"
printf "\n"
