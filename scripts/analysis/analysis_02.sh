#!/bin/bash
#SBATCH --job-name=f2_plink_ld_prune
#SBATCH --time=0-10:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --mem=32G
#SBATCH --partition=guest

## record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"
## set working directory and variables
BASEDIR=/work/fauverlab/zachpella/scatter_20
WORKDIR=${BASEDIR}/downsampled_our_data_and_online/final_vcf
# Input: the filtered VCF from the previous vcftools step
VCF_FILE=combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi.vcf.gz
OUT_PREFIX=combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi
## load modules
module purge
module load plink2
## move into VCF directory
cd ${WORKDIR}
## Step 1: Filter for linkage disequilibrium to create the prune list
echo "Step 1: Generating LD prune list..."
plink2 \
    --vcf ${VCF_FILE} \
    --double-id \
    --allow-extra-chr \
    --set-missing-var-ids @:# \
    --indep-pairwise 50 10 0.1 \
    --out ${OUT_PREFIX}
## Step 2: Prune the VCF and create a new VCF file
echo "Step 2: Exporting LD-pruned VCF..."
plink2 \
    --vcf ${VCF_FILE} \
    --double-id \
    --allow-extra-chr \
    --set-missing-var-ids @:# \
    --extract ${OUT_PREFIX}.prune.in \
    --export vcf \
    --out ${OUT_PREFIX}_pruned
echo "✓ PLINK LD pruning completed."
echo "  LD pruning list: ${OUT_PREFIX}.prune.in"
echo "  New pruned VCF: ${OUT_PREFIX}_pruned.vcf"
echo "Completed at: $(date)"
printf "\n"
