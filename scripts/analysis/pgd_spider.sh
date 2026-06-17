#!/bin/bash
#SBATCH --job-name=f3_pgdspider_conversion
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=10:00:00
#SBATCH --mem=40G
#SBATCH --partition=guest
#SBATCH --ntasks-per-node=1

## record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

# Load the PGDSpider module
module purge
module load pgdspider

BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKDIR=${BASEDIR}/downsampled_our_data_and_online/final_vcf

# Input VCF from the PLINK LD pruning step
INPUT_VCF="${WORKDIR}/combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi_pruned.vcf"

# Output directory and files
OUTPUT_DIR="${WORKDIR}"
SPID_FILE="${OUTPUT_DIR}/spid.spid"
OUTPUT_FILE="${OUTPUT_DIR}/combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi_pruned.str"

# Change to the working directory
cd "${OUTPUT_DIR}"

# Check if input VCF exists
if [ ! -f "${INPUT_VCF}" ]; then
    echo "Error: Input VCF file not found: ${INPUT_VCF}"
    exit 1
fi

echo "Converting VCF to STRUCTURE format..."
echo "Input: ${INPUT_VCF}"
echo "Output: ${OUTPUT_FILE}"

# Run the PGDSpider command
PGDSpider2-cli \
    -Xmx40G \
    -inputfile "${INPUT_VCF}" \
    -inputformat VCF \
    -outputfile "${OUTPUT_FILE}" \
    -outputformat STRUCTURE \
    -spid "${SPID_FILE}"

if [ $? -ne 0 ]; then
    echo "Error: PGDSpider conversion failed."
    exit 1
fi

echo "✓ PGDSpider conversion completed."
echo "  STRUCTURE file: ${OUTPUT_FILE}"
echo "Completed at: $(date)"
printf "\n"
