#!/bin/bash
#SBATCH --job-name=downsampled_stats_summary
#SBATCH --mail-user=zpella@unmc.edu
#SBATCH --mail-type=ALL
#SBATCH --time=0-01:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --mem=50G
#SBATCH --partition=batch

## Set working directories for downsampled data
BASEDIR=/work/fauverlab/zachpella/scatter_20/downsampled_our_data_and_online
STATSDIR=${BASEDIR}/stats
OUTDIR=${BASEDIR}

## Set reference and targets files
REFERENCEDIR=/work/fauverlab/zachpella/scatter_20/reference
REFERENCE=masked_ixodes_ref_genome.fasta
TARGETS=${REFERENCEDIR}/${REFERENCE}.bed

## Load samtools module
module load samtools/1.19

## Create a header for the comprehensive summary file
echo "Sample,Primary_Reads,Primary_Mapped,Perc_Primary_Mapped,Properly_Paired,Perc_Properly_Paired,Mean_Coverage,Coverage_5x_Percent,Coverage_10x_Percent" > ${OUTDIR}/downsampled_stats_summary.csv

echo "Processing downsampled alignment statistics..."

cd ${STATSDIR}

for i in flagstats.*.downsampled.out; do
    BASENAME=$(basename $i .downsampled.out | sed 's/flagstats\.//')
    echo "Processing $BASENAME..."

    # Extract alignment metrics
    TOTAL=$(grep "in total" $i | head -1 | awk '{print $1}')
    PRIMARY=$(grep "^[0-9]* + [0-9]* primary$" $i | awk '{print $1}')

    # Get primary mapped stats specifically
    PRIMARY_MAPPED_LINE=$(grep "primary mapped" $i)
    PRIMARY_MAPPED=$(echo "$PRIMARY_MAPPED_LINE" | awk '{print $1}')
    PERC_PRIMARY_MAPPED=$(echo "$PRIMARY_MAPPED_LINE" | awk -F'[()]' '{print $2}' | awk '{print $1}')

    # Get properly paired stats
    PAIRED_LINE=$(grep "properly paired" $i)
    PROPERLY_PAIRED=$(echo "$PAIRED_LINE" | awk '{print $1}')
    PERC_PROPERLY_PAIRED=$(echo "$PAIRED_LINE" | awk -F'[()]' '{print $2}' | awk '{print $1}')

    # Handle special case for files with 0 reads
    if [ -z "$PERC_PRIMARY_MAPPED" ]; then PERC_PRIMARY_MAPPED="0"; fi
    if [ -z "$PERC_PROPERLY_PAIRED" ]; then PERC_PROPERLY_PAIRED="0"; fi
    if [ -z "$PROPERLY_PAIRED" ]; then PROPERLY_PAIRED="0"; fi
    if [ -z "$PRIMARY_MAPPED" ]; then PRIMARY_MAPPED="0"; fi

    # Get mean coverage from averageDOC file
    AVGDOC_FILE="${STATSDIR}/averageDOC.${BASENAME}.downsampled.out"
    if [ -f "${AVGDOC_FILE}" ]; then
        MEAN_COVERAGE=$(grep "Average depth of coverage:" "${AVGDOC_FILE}" | awk '{print $5}')

        # Check if we got a valid number and format it
        if [ -n "$MEAN_COVERAGE" ] && [[ "$MEAN_COVERAGE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            MEAN_COVERAGE=$(awk "BEGIN {printf \"%.2f\", ${MEAN_COVERAGE}}")
        else
            MEAN_COVERAGE="NA"
        fi
    else
        MEAN_COVERAGE="NA"
    fi

    # Get coverage depth percentages for 5x and 10x from coverage stats
    COVERAGE_5X="NA"
    COVERAGE_10X="NA"

    # Extract from coverage file (if you ran samtools stats with -t flag)
    COVERAGE_FILE="${STATSDIR}/coverage.${BASENAME}.downsampled.out"
    if [ -f "${COVERAGE_FILE}" ]; then
        # Parse the coverage file for genome-wide coverage if available
        # This is a placeholder - adjust based on your actual coverage output format
        COVERAGE_5X=$(awk '$6 >= 5 {count++} END {if (NR>1) print (count/(NR-1))*100; else print "NA"}' "${COVERAGE_FILE}")
        COVERAGE_10X=$(awk '$6 >= 10 {count++} END {if (NR>1) print (count/(NR-1))*100; else print "NA"}' "${COVERAGE_FILE}")
    fi

    # Ensure we have valid values
    if [ -z "$COVERAGE_5X" ] || [ "$COVERAGE_5X" = "" ]; then COVERAGE_5X="NA"; fi
    if [ -z "$COVERAGE_10X" ] || [ "$COVERAGE_10X" = "" ]; then COVERAGE_10X="NA"; fi

    # Output to comprehensive summary
    echo "$BASENAME,$PRIMARY,$PRIMARY_MAPPED,$PERC_PRIMARY_MAPPED,$PROPERLY_PAIRED,$PERC_PROPERLY_PAIRED,$MEAN_COVERAGE,$COVERAGE_5X,$COVERAGE_10X" >> ${OUTDIR}/downsampled_stats_summary.csv
done

echo "Downsampled statistics summary created: ${OUTDIR}/downsampled_stats_summary.csv"

## Create a tab-separated version for command line viewing
sed 's/,/\t/g' ${OUTDIR}/downsampled_stats_summary.csv > ${OUTDIR}/downsampled_stats_summary.tsv
echo "Tab-separated version created: ${OUTDIR}/downsampled_stats_summary.tsv"

## Print summary to stdout
echo ""
echo "============================================================================"
echo "DOWNSAMPLED DATA SUMMARY"
echo "============================================================================"
column -t -s $'\t' ${OUTDIR}/downsampled_stats_summary.tsv
echo "============================================================================"
