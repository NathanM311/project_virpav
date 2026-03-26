#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 01 : SUPPRESSION DU PHAGE PhiX174 AVEC BOWTIE2
# ------------------------------------------------------------------

# Arrête le script immédiatement s'il y a une erreur
set -e

SAMPLE=${1:-"MOCK_SAMPLE"}
# On utilise $(pwd) pour forcer le chemin ABSOLU (/mnt/MERSEA/...)
BASE_DIR=$(pwd)

INPUT_DIR="${BASE_DIR}/01_data/raw_data/${SAMPLE}"
OUTPUT_DIR="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/databases/phix"

mkdir -p $OUTPUT_DIR
mkdir -p $DB_DIR

# 1. Indexation
if [ ! -f "${DB_DIR}/phix.1.bt2" ]; then
    echo "📥 Téléchargement et indexation de PhiX..."
    wget -q -O ${DB_DIR}/phix.fasta "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001422.1&rettype=fasta&retmode=text"
    bowtie2-build ${DB_DIR}/phix.fasta ${DB_DIR}/phix > /dev/null
fi

R1="${INPUT_DIR}/${SAMPLE}_R1.fastq.gz"
R2="${INPUT_DIR}/${SAMPLE}_R2.fastq.gz"

echo "==================================================="
echo "🔍 VÉRIFICATION DES FICHIERS (Chemins absolus) :"
ls -lh $R1
ls -lh $R2
echo "==================================================="

echo "🦠 Nettoyage du PhiX pour l'échantillon : $SAMPLE"

# Lancement de Bowtie2
bowtie2 -x ${DB_DIR}/phix \
        -1 $R1 -2 $R2 \
        --threads 8 \
        --un-conc-gz ${OUTPUT_DIR}/${SAMPLE}_no_phix_R%.fastq.gz \
        -S /dev/null 2> ${OUTPUT_DIR}/${SAMPLE}_phix_stats.txt

echo "==================================================="
echo "📊 STATISTIQUES DE NETTOYAGE PHIX :"
cat ${OUTPUT_DIR}/${SAMPLE}_phix_stats.txt
echo "==================================================="
echo "✅ Terminé avec succès ! Tes reads propres sont ici :"
echo "   ${OUTPUT_DIR}"
echo "==================================================="