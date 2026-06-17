#!/bin/bash
#SBATCH --job-name=f3_admixture_cv
#SBATCH --time=1-00:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --partition=guest

## Record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

## Set working directory and variables
BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKDIR=${BASEDIR}/downsampled_our_data_and_online/final_vcf
INPUT=combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi.LD_pruned
ADMIX_INPUT=${INPUT}_admixture

## Load modules
module purge
module load admixture/1.3

## Move into working directory
cd ${WORKDIR}

## Verify input files exist
if [ ! -f "${INPUT}.bed" ]; then
    echo "Error: Input file not found: ${INPUT}.bed"
    exit 1
fi

echo "Input files:"
ls -lh ${INPUT}.bed ${INPUT}.bim ${INPUT}.fam
printf "\n"

## Fix chromosome codes for ADMIXTURE (must be integers)
echo "Converting chromosome names to integers for ADMIXTURE..."

# Create a mapping of unique chromosome names to integers
awk '{print $1}' ${INPUT}.bim | sort -u | awk '{print $1, NR}' > chrom_map.txt

echo "Chromosome mapping:"
cat chrom_map.txt
printf "\n"

# Apply mapping to create new .bim file
awk 'NR==FNR {map[$1]=$2; next} {$1=map[$1]; print}' chrom_map.txt ${INPUT}.bim > ${ADMIX_INPUT}.bim

# Copy .bed and .fam files (they don't need modification)
cp ${INPUT}.bed ${ADMIX_INPUT}.bed
cp ${INPUT}.fam ${ADMIX_INPUT}.fam

echo "Created ADMIXTURE-compatible files: ${ADMIX_INPUT}.*"
printf "\n"

## Run ADMIXTURE with cross-validation for K=1 through K=6
for K in {1..6}; do
    echo "============================================"
    echo "Running ADMIXTURE with K=${K}..."
    echo "============================================"
    admixture --cv ${ADMIX_INPUT}.bed ${K} -j8 | tee log_K${K}.out
    printf "\n"
done

## Extract CV errors for easy comparison
echo "============================================"
echo "Cross-validation error summary:"
echo "============================================"
grep -h "CV error" log_K*.out > cv_errors_summary.txt
cat cv_errors_summary.txt

echo ""
echo "✓ ADMIXTURE analysis completed"
echo "  Output files: ${ADMIX_INPUT}.*.Q (ancestry fractions)"
echo "                ${ADMIX_INPUT}.*.P (allele frequencies)"
echo "  CV summary:   cv_errors_summary.txt"
echo "  Chrom map:    chrom_map.txt"
echo "  Log files:    log_K*.out"
echo "Completed at: $(date)"
printf "\n"
