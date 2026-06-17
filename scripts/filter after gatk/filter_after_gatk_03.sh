#!/bin/bash
#SBATCH --job-name=select_passing_ixodes
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=80G
#SBATCH --time=4-22:00:00
#SBATCH --error=%x_%j.err
#SBATCH --output=%x_%j.out

module purge
module load gatk4/4.6

BASEDIR=/work/fauverlab/zachpella/scatter_20
FINAL_VCF_DIR="${BASEDIR}/downsampled_our_data_and_online/final_vcf"

# INPUT_FILTERED_VCF from the previous VariantFiltration step
INPUT_FILTERED_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_filtered.vcf.gz"

# Output passing-only VCF
OUTPUT_PASSING_ONLY_VCF="${FINAL_VCF_DIR}/combined_ixodes_all_variants_snps_passing_only.vcf.gz"

echo "Creating a VCF with only the variants that passed the filters..."
echo "Input filtered VCF: ${INPUT_FILTERED_VCF}"
echo "Output passing-only VCF: ${OUTPUT_PASSING_ONLY_VCF}"

gatk --java-options "-Xms2G -Xmx75G" SelectVariants \
    --variant "${INPUT_FILTERED_VCF}" \
    --output "${OUTPUT_PASSING_ONLY_VCF}" \
    --exclude-filtered

if [ $? -ne 0 ]; then
    echo "Error: SelectVariants (passing only) failed."
    exit 1
fi

echo "SelectVariants completed successfully."
echo "VCF with passing-only variants created: ${OUTPUT_PASSING_ONLY_VCF}"
echo "Script finished successfully."
