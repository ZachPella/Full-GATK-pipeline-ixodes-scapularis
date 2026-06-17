#!/bin/bash
#SBATCH --job-name=multiqc_report
#SBATCH --time=10:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --partition=guest

BASEDIR="/work/fauverlab/zachpella/scatter_20/QC_alignment_preprocessing_haplotype"
QCDIR="${BASEDIR}/fastqc_reports"
OUTDIR="${BASEDIR}/multiqc_report"

mkdir -p "${OUTDIR}"

echo "Starting MultiQC at: $(date)"
echo "Input directory: ${QCDIR}"
echo "Output directory: ${OUTDIR}"

module purge
module load multiqc

multiqc "${QCDIR}" --outdir "${OUTDIR}" --filename "multiqc_report"

if [[ -f "${OUTDIR}/multiqc_report.html" ]]; then
    echo "✓ MultiQC completed successfully"
else
    echo "✗ Error: MultiQC report not created"
    exit 1
fi

echo "Completed at: $(date)"
