#!/bin/bash
#SBATCH --job-name=f2_plink_ld_pca
#SBATCH --time=0-10:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --mem=32G
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
JOINTVCF=combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi
OUTPUT_PREFIX=${JOINTVCF}.LD_pruned
# Load modules
module purge
module load plink2
# Move into VCF directory
cd ${WORKDIR}
# Filter for linkage disequilibrium
plink2 \
    --vcf ${JOINTVCF}.vcf.gz \
    --double-id \
    --allow-extra-chr \
    --set-missing-var-ids @:# \
    --indep-pairwise 50 10 0.1 \
    --out ${OUTPUT_PREFIX}
# Prune and create PCA
plink2 \
    --vcf ${JOINTVCF}.vcf.gz \
    --double-id \
    --allow-extra-chr \
    --set-missing-var-ids @:# \
    --extract ${OUTPUT_PREFIX}.prune.in \
    --make-bed \
    --pca 20 \
    --out ${OUTPUT_PREFIX}
echo "✓ PLINK analysis completed"
echo "  LD pruning results: ${OUTPUT_PREFIX}.prune.in/out"
echo "  PCA results: ${OUTPUT_PREFIX}.eigenvec/eigenval"
echo "  PLINK files: ${OUTPUT_PREFIX}.bed/bim/fam"
echo "Completed at: $(date)"
printf "\n"
