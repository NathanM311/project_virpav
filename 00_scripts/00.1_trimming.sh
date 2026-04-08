#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 01 : NETTOYAGE QUALITÉ ET ADAPTATEURS (TRIMGALORE)
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Dossiers
INPUT_DIR="${BASE_DIR}/01_data/raw_data/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/01_trimmed"
mkdir -p $OUT_DIR

# Identification des fichiers (basé sur tes noms de fichiers Illumina)
R1="${INPUT_DIR}/${SAMPLE}_S10_L001_R1_001.fastq.gz"
R2="${INPUT_DIR}/${SAMPLE}_S10_L001_R2_001.fastq.gz"

echo "✂️ Trimming en cours pour : $SAMPLE"

# Utilisation de TrimGalore (souvent dans l'env 'rnaseq')
trim_galore --paired \
            --quality 20 \
            --fastqc \
            --illumina \
            --gzip \
            --cores 14 \
            -o $OUT_DIR \
            $R1 $R2

echo "✅ Trimming terminé. Fichiers dans : $OUT_DIR"