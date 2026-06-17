#!/bin/bash
#SBATCH --job-name=downsample_S1
#SBATCH --time=2-00:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --partition=guest

## ============================================================================
## DOWNSAMPLING SCRIPT FOR S1 (NEW) SAMPLES
## Purpose: Downsample 8 S1 samples from ~30x to ~8x coverage to match S2 baseline
## ============================================================================

## Set working directories
BASEDIR="/work/fauverlab/zachpella/scatter_20"
INPUT_BAMDIR="${BASEDIR}/QC_alignment_preprocessing_haplotype/bam_files"
OUTDIR="${BASEDIR}/downsampled_our_data_and_online"
WORKDIR="${OUTDIR}/bam_files"
FRACTION_FILE="${OUTDIR}/scripts/downsample_fractions_S1.txt"

## Create output directories
mkdir -p "${WORKDIR}"
mkdir -p "${OUTDIR}/stats"

## Move into output directory
cd "${WORKDIR}"

## Load modules
module purge
module load samtools/1.20

## Check if fraction file exists
if [ ! -f "${FRACTION_FILE}" ]; then
    echo "Error: Fraction file not found: ${FRACTION_FILE}"
    echo "Please create the fraction file at: ${FRACTION_FILE}"
    exit 1
fi

echo "============================================================================"
echo "Starting downsampling of S1 samples"
echo "Target: ~135M reads (~8.3x coverage to match S2 samples)"
echo "Input BAM directory: ${INPUT_BAMDIR}"
echo "Output BAM directory: ${WORKDIR}"
echo "Output stats directory: ${OUTDIR}/stats"
echo "Fraction file: ${FRACTION_FILE}"
echo "============================================================================"
printf "\n"

## Downsample while loop
while IFS="," read -r BAMNAME FRACTION
do
    echo "------------------------------------------------------------------------"
    echo "Processing: ${BAMNAME}"
    echo "Downsampling to ${FRACTION} of reads ($(echo "${FRACTION} * 100" | bc -l | xargs printf "%.2f")%)"
    echo "------------------------------------------------------------------------"
    
    # Input file should be the sorted, mapped BAM
    INPUT_BAM="${INPUT_BAMDIR}/${BAMNAME}.sorted.mapped.bam"
    
    # Check if input file exists
    if [ ! -f "${INPUT_BAM}" ]; then
        echo "✗ Warning: Input BAM not found: ${INPUT_BAM}"
        echo "  Trying alternative: ${INPUT_BAMDIR}/${BAMNAME}.sorted.bam"
        INPUT_BAM="${INPUT_BAMDIR}/${BAMNAME}.sorted.bam"
        
        if [ ! -f "${INPUT_BAM}" ]; then
            echo "✗ Error: No BAM file found for ${BAMNAME}. Skipping."
            continue
        fi
    fi
    
    echo "Input BAM: ${INPUT_BAM}"
    
    # Downsample the BAM file
    # -b: output BAM format
    # -s: random seed + fraction (e.g., 42.2542 = seed 42, fraction 0.2542)
    echo "Step 1: Downsampling..."
    samtools view -@ 4 -b -s 42${FRACTION} "${INPUT_BAM}" > "${WORKDIR}/${BAMNAME}.downsampled.bam"
    
    if [ ! -s "${WORKDIR}/${BAMNAME}.downsampled.bam" ]; then
        echo "✗ Error: Downsampling failed for ${BAMNAME}"
        continue
    fi
    
    echo "✓ Downsampling complete"
    
    # Sort the downsampled BAM
    echo "Step 2: Sorting..."
    samtools sort -@ 4 -m 8G "${WORKDIR}/${BAMNAME}.downsampled.bam" \
        -o "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam" \
        -T "${WORKDIR}/${BAMNAME}.tmp"
    
    if [ ! -s "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam" ]; then
        echo "✗ Error: Sorting failed for ${BAMNAME}"
        continue
    fi
    
    echo "✓ Sorting complete"
    
    # Remove unsorted downsampled BAM to save space
    rm "${WORKDIR}/${BAMNAME}.downsampled.bam"
    
    # Index the sorted BAM
    echo "Step 3: Indexing..."
    samtools index "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam"
    
    # Generate statistics
    echo "Step 4: Generating statistics..."
    
    # Flagstat
    samtools flagstat "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam" \
        > "${OUTDIR}/stats/flagstats.${BAMNAME}.downsampled.out"
    
    # Coverage stats
    samtools coverage "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam" \
        > "${OUTDIR}/stats/coverage.${BAMNAME}.downsampled.out"
    
    # Average depth
    samtools depth -a "${WORKDIR}/${BAMNAME}.downsampled.sorted.bam" \
        > "${OUTDIR}/stats/${BAMNAME}.downsampled.depth"
    AVGDOC=$(awk '{ total += $3; count++ } END { print total/count }' "${OUTDIR}/stats/${BAMNAME}.downsampled.depth")
    echo "Average depth of coverage: ${AVGDOC}" > "${OUTDIR}/stats/averageDOC.${BAMNAME}.downsampled.out"
    
    # Clean up depth file to save space (optional - comment out if you want to keep it)
    rm "${OUTDIR}/stats/${BAMNAME}.downsampled.depth"
    
    echo "✓ Statistics complete"
    echo "  Average coverage: ${AVGDOC}x"
    echo "✓ Processing complete for ${BAMNAME}"
    printf "\n"
    
done < "${FRACTION_FILE}"

echo "============================================================================"
echo "All downsampling complete!"
echo "Output BAMs in: ${WORKDIR}"
echo "Output stats in: ${OUTDIR}/stats"
echo "============================================================================"
