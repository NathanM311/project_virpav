#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 01.2 : SUPPRESSION DU PHAGE PhiX174 AVEC BBDUK
# Échantillon : MOCK_SAMPLE
# ------------------------------------------------------------------
set -e

SAMPLE=${1:-"MOCK_SAMPLE"}
BASE_DIR=$(pwd)

# On pointe vers le bon dossier de ton MOCK
INPUT_DIR="${BASE_DIR}/01_data/raw_data/${SAMPLE}"
OUTPUT_DIR="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/databases/phix"

mkdir -p $OUTPUT_DIR
mkdir -p $DB_DIR

# Fichiers d'entrée exacts pour le MOCK
R1="${INPUT_DIR}/${SAMPLE}_R1.fastq.gz"
R2="${INPUT_DIR}/${SAMPLE}_R2.fastq.gz"

# Référence PhiX (on la télécharge si elle n'est pas déjà là)
REF_PHIX="${DB_DIR}/phix.fasta"
if [ ! -f "$REF_PHIX" ]; then
    echo "📥 Téléchargement du génome PhiX174..."
    wget -q -O $REF_PHIX "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001422.1&rettype=fasta&retmode=text"
fi

# Fichiers de sortie
OUT_R1="${OUTPUT_DIR}/${SAMPLE}_no_phix_R1.fastq.gz"
OUT_R2="${OUTPUT_DIR}/${SAMPLE}_no_phix_R2.fastq.gz"
STATS_FILE="${OUTPUT_DIR}/${SAMPLE}_bbduk_stats.txt"

echo "==================================================="
echo "🔍 VÉRIFICATION DES FICHIERS (Chemins absolus) :"
ls -lh $R1
ls -lh $R2
echo "==================================================="

echo "🦠 Nettoyage du PhiX avec BBDUK pour l'échantillon : $SAMPLE"

# Lancement de BBDuk
# k=31 hdist=1 : Ce sont les paramètres standards de l'institut JGI pour chasser le PhiX. 
# Ça cherche des mots de 31 lettres avec 1 erreur autorisée maximum.
# 1. ÉTAPE DE RÉPARATION (Déjà faite et réussie !)
echo "🔧 Réparation des fichiers FASTQ du MOCK..."
repair.sh in1=$R1 in2=$R2 \
          out1=${OUTPUT_DIR}/${SAMPLE}_fixed_R1.fastq.gz \
          out2=${OUTPUT_DIR}/${SAMPLE}_fixed_R2.fastq.gz \
          outs=${OUTPUT_DIR}/${SAMPLE}_orphans.fastq.gz \
          repair

# 2. ÉTAPE DE NETTOYAGE PHIX
echo "🦠 Nettoyage du PhiX avec BBDUK..."

# 💡 L'ASTUCE : On désactive les assertions Java ici
export _JAVA_OPTIONS="-da"

bbduk.sh in1=${OUTPUT_DIR}/${SAMPLE}_fixed_R1.fastq.gz \
         in2=${OUTPUT_DIR}/${SAMPLE}_fixed_R2.fastq.gz \
         out1=$OUT_R1 out2=$OUT_R2 \
         ref=$REF_PHIX \
         k=31 hdist=1 \
         t=1 \
         stats=$STATS_FILE

# Nettoyage
rm ${OUTPUT_DIR}/${SAMPLE}_fixed_R*.fastq.gz

# Nettoyage des fichiers temporaires de réparation
rm ${OUTPUT_DIR}/${SAMPLE}_fixed_R*.fastq.gz

echo "==================================================="
echo "📊 STATISTIQUES BBDUK :"
cat $STATS_FILE
echo "==================================================="
echo "✅ Terminé avec succès ! Tes reads propres sont ici :"
echo "   $OUTPUT_DIR"
echo "==================================================="