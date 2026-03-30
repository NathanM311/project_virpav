#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 05 : DÉRÉPLICATION DES ASSEMBLAGES VIRAUX (MMseqs2 à 99%)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# 1. Correction : Nom dynamique (MOCK_SAMPLE par défaut)
SAMPLE=${1:-"MOCK_SAMPLE"}

IN_DIR="${BASE_DIR}/02_results/04_assembly/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/06_clustering/${SAMPLE}"
mkdir -p $OUT_DIR

# Fichiers d'entrée
SPADES="$IN_DIR/noribosome_rnaspades/transcripts.fasta"
# 2. Correction : Remplacement du point par un slash pour Trinity
TRINITY="$IN_DIR/noribosome_trinity.Trinity.fasta" 
BLOOM="$IN_DIR/noribosome_rnabloom/rnabloom.transcripts.fa"
COMBINED="$OUT_DIR/${SAMPLE}_combined_assembly.fasta"

echo "===================================================================="
echo "🚀 DÉMARRAGE DE LA DÉRÉPLICATION (MMseqs2 - STRICT 99%)"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

echo "📦 1. Fusion des 3 assemblages (SPAdes, Trinity, Bloom)..."
# On fusionne silencieusement pour ignorer un assembleur manquant éventuel
cat $SPADES $TRINITY $BLOOM > $COMBINED 2>/dev/null

echo "📊 Nombre total de contigs avant nettoyage :"
grep -c "^>" $COMBINED

echo "🔄 Vérification/Création de l'environnement MMseqs2..."
source $HOME/miniconda3/etc/profile.d/conda.sh

if ! conda info --envs | grep -q "env_mmseqs"; then
    echo "Création de env_mmseqs en cours..."
    conda create -n env_mmseqs -c bioconda -c conda-forge mmseqs2 -y
fi
conda activate env_mmseqs

echo "🧬 2. Lancement de MMseqs2 (easy-cluster à 99%)..."
mmseqs easy-cluster $COMBINED $OUT_DIR/mmseqs_out $OUT_DIR/tmp \
    --min-seq-id 0.99 \
    -c 0.90 \
    --cov-mode 1 \
    --dbtype 2 \
    --threads 14

echo "📊 Nombre de contigs uniques restants après nettoyage :"
grep -c "^>" $OUT_DIR/mmseqs_out_rep_seq.fasta

rm -rf $OUT_DIR/tmp
conda deactivate

echo "✅ DÉRÉPLICATION TERMINÉE !"
echo "📁 Fichier final : $OUT_DIR/mmseqs_out_rep_seq.fasta"