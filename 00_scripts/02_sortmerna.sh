#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 02 : SORTMERNA - NETTOYAGE TOTAL (VERSION TURBO + SÉCURISÉE)
# ------------------------------------------------------------------

# 1. SÉCURITÉ ABSOLUE : S'arrête si un fichier manque ou plante !
set -e

# 2. ÉCOUTE LE MASTER SCRIPT
SAMPLE=${1:-"MOCK_SAMPLE"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate rnaseq

# 3. LES BONS DOSSIERS (Vérifie que c'est bien là que le 01 met les fichiers)
INPUT_DIR="$BASE_DIR/02_results/02_phix_removed/${SAMPLE}"
OUTPUT_DIR="$BASE_DIR/02_results/03_sortmerna"
DB_DIR="$BASE_DIR/01_data/sortmerna"

SAMPLE_OUT_DIR="$OUTPUT_DIR/$SAMPLE"
mkdir -p $SAMPLE_OUT_DIR

# 4. LES BONNES EXTENSIONS (.fq.gz)
R1="${INPUT_DIR}/${SAMPLE}_no_phix_R1.fq.gz"
R2="${INPUT_DIR}/${SAMPLE}_no_phix_R2.fq.gz"
REF_DB="${DB_DIR}/smr_v4.3_default_db.fasta"

# ==================================================================
# 5. ASTUCE DU DISQUE LOCAL (Pour ne pas bloquer 35 heures)
LOCAL_WORKDIR="/tmp/sortmerna_${SAMPLE}"
mkdir -p $LOCAL_WORKDIR
# ==================================================================

echo "==================================================="
echo "🧬 Tri SortMeRNA TOTAL pour : $SAMPLE"
echo "==================================================="

# Lancement de la bête sur le SSD local
sortmerna \
    --ref $REF_DB \
    --reads $R1 \
    --reads $R2 \
    --workdir $LOCAL_WORKDIR \
    --aligned $SAMPLE_OUT_DIR/${SAMPLE}_ribosome \
    --other $SAMPLE_OUT_DIR/${SAMPLE}_noribosome \
    --paired_in \
    --out2 \
    --fastx \
    --threads 14

echo "🗜️ Vérification et compression des résultats..."
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_ribosome_fwd.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_ribosome_rev.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_noribosome_fwd.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_noribosome_rev.fq 2>/dev/null || true

# Nettoyage du disque local
rm -rf $LOCAL_WORKDIR

echo "✅ NETTOYAGE TERMINÉ ET RANGÉ AVEC SUCCÈS DANS : $SAMPLE_OUT_DIR"