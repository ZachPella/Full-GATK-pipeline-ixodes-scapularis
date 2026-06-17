#!/bin/bash
#SBATCH --job-name=f1_VCFtools_filter
#SBATCH --time=2-00:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --mem=80G
#SBATCH --partition=guest

# Record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKDIR=${BASEDIR}/downsampled_our_data_and_online/final_vcf

# Input VCF from the previous SelectVariants (passing only) step
INPUT_VCF=${WORKDIR}/combined_ixodes_all_variants_snps_passing_only.vcf.gz

# Output prefix matching the input naming scheme
OUTPUT_VCF_PREFIX=combined_ixodes_all_variants_snps_passing_only

# Move into working directory
cd ${WORKDIR}

# Load modules
module purge
module load vcftools/0.1

# Check if the input VCF exists
if [ ! -f "${INPUT_VCF}" ]; then
    echo "Error: Input VCF file not found: ${INPUT_VCF}"
    exit 1
fi

echo "Filtering input VCF: ${INPUT_VCF}"
echo "Applying filters: MAF >= 0.1, max-missing >= 0.95, MAC >= 2, biallelic only"

vcftools --gzvcf "${INPUT_VCF}" \
    --maf 0.1 \
    --max-missing 0.95 \
    --mac 2 \
    --min-alleles 2 \
    --max-alleles 2 \
    --recode \
    --stdout | gzip -c > ${OUTPUT_VCF_PREFIX}.maf01.miss05.mac2.bi.vcf.gz

if [ $? -ne 0 ]; then
    echo "Error: VCFtools filtering failed."
    exit 1
fi

echo "VCFtools filtering completed successfully."
echo "Filtered VCF saved to: ${WORKDIR}/${OUTPUT_VCF_PREFIX}.maf01.miss05.mac2.bi.vcf.gz"
echo "Completed at: $(date)"
printf "\n"
