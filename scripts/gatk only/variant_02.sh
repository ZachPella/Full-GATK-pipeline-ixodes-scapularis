#!/bin/bash
#SBATCH --mem=100G
#SBATCH --time=4-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --job-name=gatk4_genomicsdbimport_downsampled
#SBATCH --error=gatk4_genomicsdbimport_downsampled.%J.err
#SBATCH --output=gatk4_genomicsdbimport_downsampled.%J.out
#SBATCH --partition=guest
#SBATCH --array=0-19

module purge
module load gatk4/4.6

export TILEDB_DISABLE_FILE_LOCKING=1

## Record relevant job info
START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)
echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

## Set directories
BASEDIR=/work/fauverlab/zachpella/scatter_20/downsampled_our_data_and_online
REFERENCEDIR=/work/fauverlab/zachpella/scatter_20/reference
REFERENCE=masked_ixodes_ref_genome.fasta
SCATTER_COUNT=20
CHUNK=$(printf "%04d" ${SLURM_ARRAY_TASK_ID})

# Use the global intervals directory
INTERVAL_LIST_CHUNK="/work/fauverlab/zachpella/scatter_20/global_intervals/${CHUNK}-scattered.interval_list"

# TWO GVCF directories:
# 1. Downsampled samples (8 samples)
DOWNSAMPLED_GVCF_DIR=${BASEDIR}/genotyping/scattered_gvcfs
# 2. Original samples (everything else)
ORIGINAL_GVCF_DIR=/work/fauverlab/zachpella/scatter_20/QC_alignment_preprocessing_haplotype/genotyping/scattered_gvcfs

# Samples that were downsampled - look for these in DOWNSAMPLED_GVCF_DIR
DOWNSAMPLED_SAMPLES="19055 19081A SD1 SD7 SD9 BEI2 BEI3 BEI5"

# Create job-specific directories on scratch partition
mkdir -p /scratch/$SLURM_JOBID/tmp
mkdir -p /scratch/$SLURM_JOBID/output

## Sample list
SAMPLE_LIST="${BASEDIR}/sample_list.txt"

if [ ! -f "$SAMPLE_LIST" ]; then
    echo "Error: Sample list file not found at ${SAMPLE_LIST}. Exiting."
    exit 1
fi

## Verify interval file exists
if [ ! -f "$INTERVAL_LIST_CHUNK" ]; then
    echo "Error: Interval list not found at ${INTERVAL_LIST_CHUNK}. Exiting."
    exit 1
fi

## Build the list of all GVCFs to import for this chunk
GVCF_INPUT=""
GVCF_COUNT=0
MISSING_SAMPLES=""

echo "Reading samples from ${SAMPLE_LIST}..."
echo "Building GVCF input list for chunk ${CHUNK}..."
echo "Downsampled GVCF dir: ${DOWNSAMPLED_GVCF_DIR}"
echo "Original GVCF dir: ${ORIGINAL_GVCF_DIR}"
echo ""

while IFS= read -r SAMPLE; do
    # Skip empty lines and comments
    [[ -z "$SAMPLE" || "$SAMPLE" =~ ^# ]] && continue

    # Check if this sample was downsampled
    IS_DOWNSAMPLED=false
    for DS_SAMPLE in ${DOWNSAMPLED_SAMPLES}; do
        if [[ "$SAMPLE" == "$DS_SAMPLE" ]]; then
            IS_DOWNSAMPLED=true
            break
        fi
    done

    # Pick the correct directory based on whether sample was downsampled
    if [ "$IS_DOWNSAMPLED" = true ]; then
        SAMPLE_GVCF="${DOWNSAMPLED_GVCF_DIR}/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf"
    else
        SAMPLE_GVCF="${ORIGINAL_GVCF_DIR}/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf"
    fi

    if [ -f "$SAMPLE_GVCF" ]; then
        GVCF_INPUT="${GVCF_INPUT} -V ${SAMPLE_GVCF}"
        ((GVCF_COUNT++))
    else
        echo "Warning: GVCF not found for sample ${SAMPLE}: ${SAMPLE_GVCF}"
        MISSING_SAMPLES="${MISSING_SAMPLES} ${SAMPLE}"
    fi
done < "$SAMPLE_LIST"

if [ -z "$GVCF_INPUT" ]; then
    echo "Error: No GVCF files found for chunk ${CHUNK}. Exiting."
    exit 1
fi

echo ""
echo "Found ${GVCF_COUNT} valid GVCF files for chunk ${CHUNK}."
if [ -n "$MISSING_SAMPLES" ]; then
    echo "Warning: Missing GVCFs for the following samples:${MISSING_SAMPLES}"
fi

## Set output paths
FINAL_GENOMICSDB_PATH="${BASEDIR}/genotyping/genomicsdb_chunks/chunk_${CHUNK}"
SCRATCH_GENOMICSDB_PATH="/scratch/$SLURM_JOBID/output/genomicsdb_chunk_${CHUNK}"

## Clean up old directory if it exists
if [ -d "$FINAL_GENOMICSDB_PATH" ]; then
    echo "Removing existing GenomicsDB directory from ${FINAL_GENOMICSDB_PATH}..."
    rm -rf ${FINAL_GENOMICSDB_PATH}
fi

## Create final output directory
mkdir -p "${BASEDIR}/genotyping/genomicsdb_chunks"

# Run GenomicsDBImport for this chunk
echo ""
echo "Running GenomicsDBImport on ${GVCF_COUNT} samples for chunk ${CHUNK}..."
gatk --java-options "-Djava.io.tmpdir=/scratch/$SLURM_JOBID -Xms2G -Xmx69G -XX:ParallelGCThreads=2" \
    GenomicsDBImport \
    --genomicsdb-workspace-path ${SCRATCH_GENOMICSDB_PATH} \
    --genomicsdb-shared-posixfs-optimizations true \
    --tmp-dir /scratch/$SLURM_JOBID/tmp \
    ${GVCF_INPUT} \
    -L ${INTERVAL_LIST_CHUNK} \
    --reference ${REFERENCEDIR}/${REFERENCE}

# Check if GenomicsDBImport succeeded
if [ $? -ne 0 ]; then
    echo "Error: GenomicsDBImport failed for chunk ${CHUNK}"
    exit 1
fi

echo "GenomicsDBImport completed. Workspace created on scratch at ${SCRATCH_GENOMICSDB_PATH}"

# Copy GenomicsDB from scratch to the final location
echo "Copying GenomicsDB from scratch to ${FINAL_GENOMICSDB_PATH}..."
cp -r ${SCRATCH_GENOMICSDB_PATH} ${FINAL_GENOMICSDB_PATH}

# Verify copy succeeded
if [ ! -d "$FINAL_GENOMICSDB_PATH" ]; then
    echo "Error: Failed to copy GenomicsDB to final location"
    exit 1
fi

echo "Final GenomicsDB workspace for chunk ${CHUNK} located at ${FINAL_GENOMICSDB_PATH}"
echo "Completed at: $(date)"
printf "\n"
