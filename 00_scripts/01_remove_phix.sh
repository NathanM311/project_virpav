#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 01 : SUPPRESSION DU PHAGE PhiX174 AVEC BOWTIE2
# Échantillon : AC16
# ------------------------------------------------------------------

INPUT_DIR="02_results/01_trimmed"
OUTPUT_DIR="02_results/02_phix_removed/${SAMPLE}"
DB_DIR="01_data/databases/phix"
SAMPLE="10-21D-AC16"

mkdir -p $OUTPUT_DIR
mkdir -p $DB_DIR

# 1. Téléchargement et indexation de PhiX (si pas déjà fait)
if [ ! -f "${DB_DIR}/phix.1.bt2" ]; then
    echo "📥 Téléchargement du génome PhiX174 (NC_001422.1)..."
    wget -q -O ${DB_DIR}/phix.fasta "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001422.1&rettype=fasta&retmode=text"
    echo "🔨 Indexation Bowtie2..."
    bowtie2-build ${DB_DIR}/phix.fasta ${DB_DIR}/phix > /dev/null
fi

R1=$(ls ${INPUT_DIR}/${SAMPLE}*R1*.fq.gz)
R2=$(ls ${INPUT_DIR}/${SAMPLE}*R2*.fq.gz)

echo "==================================================="
echo "🦠 Nettoyage du PhiX pour l'échantillon : $SAMPLE"
echo "==================================================="

# Lancement de Bowtie2
# --un-conc-gz : sauvegarde les paires qui ne mappent PAS sur PhiX
# -S /dev/null : on jette les alignements (fichier SAM), pour économiser l'espace
bowtie2 -x ${DB_DIR}/phix \
        -1 $R1 -2 $R2 \
        --threads 8 \
        --un-conc-gz ${OUTPUT_DIR}/${SAMPLE}_no_phix_R%.fq.gz \
        -S /dev/null

echo "✅ Terminé ! Les reads propres sont dans $OUTPUT_DIR"
