#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 01 : SUPPRESSION DU PHAGE PhiX174 AVEC BOWTIE2 (VERSION TURBO)
# ------------------------------------------------------------------

# Arrête le script immédiatement s'il y a une erreur
set -e

SAMPLE=${1:-"MOCK_SAMPLE"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Dossiers sur le réseau MERSEA
INPUT_DIR="${BASE_DIR}/02_results/01_trimmed"
OUTPUT_DIR="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/databases/phix"

mkdir -p $OUTPUT_DIR
mkdir -p $DB_DIR

# ==================================================================
# ⚡ CRÉATION DE L'ESPACE DE TRAVAIL LOCAL (SSD de la VM) ⚡
LOCAL_TMP="/tmp/phix_${SAMPLE}"
mkdir -p $LOCAL_TMP
# ==================================================================

# 1. Indexation de la base de données (si pas déjà fait)
if [ ! -f "${DB_DIR}/phix.1.bt2" ]; then
    echo "📥 Téléchargement et indexation de PhiX..."
    wget -q -O ${DB_DIR}/phix.fasta "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001422.1&rettype=fasta&retmode=text"
    bowtie2-build ${DB_DIR}/phix.fasta ${DB_DIR}/phix > /dev/null
fi

# 2. Détection de tes fichiers trimmés (utilisation de ls pour capter _val_1.fq.gz)
R1=$(ls ${INPUT_DIR}/${SAMPLE}*R1*.f*q.gz)
R2=$(ls ${INPUT_DIR}/${SAMPLE}*R2*.f*q.gz)

echo "==================================================="
echo "🔍 VÉRIFICATION DES FICHIERS :"
ls -lh $R1
ls -lh $R2
echo "==================================================="
echo "🦠 Nettoyage du PhiX pour l'échantillon : $SAMPLE"

# 3. Lancement de Bowtie2 (Écriture des fastq.gz sur le /tmp)
# -S /dev/null jette l'alignement pour ne pas saturer le disque
bowtie2 -x ${DB_DIR}/phix \
        -1 $R1 -2 $R2 \
        --threads 14 \
        --un-conc-gz ${LOCAL_TMP}/${SAMPLE}_no_phix_R%.fq.gz \
        -S /dev/null 2> ${OUTPUT_DIR}/${SAMPLE}_phix_stats.txt

# 4. Transfert du /tmp vers MERSEA
echo "🚚 Transfert des fichiers propres vers MERSEA..."
cp ${LOCAL_TMP}/${SAMPLE}_no_phix_R1.fq.gz ${OUTPUT_DIR}/
cp ${LOCAL_TMP}/${SAMPLE}_no_phix_R2.fq.gz ${OUTPUT_DIR}/

# 5. Nettoyage du SSD local
rm -rf $LOCAL_TMP

echo "==================================================="
echo "📊 STATISTIQUES DE NETTOYAGE PHIX :"
cat ${OUTPUT_DIR}/${SAMPLE}_phix_stats.txt
echo "==================================================="
echo "✅ Terminé avec succès ! Tes reads propres sont ici :"
echo "   ${OUTPUT_DIR}"
echo "==================================================="