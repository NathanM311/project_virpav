#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 02 : SORTMERNA - NETTOYAGE TOTAL (Base Unifiée 140 Mo)
# ------------------------------------------------------------------

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
INPUT_DIR="$BASE_DIR/02_results/02_phix_removed/MOCK_SAMPLE"
OUTPUT_DIR="$BASE_DIR/02_results/03_sortmerna"
DB_DIR="$BASE_DIR/01_data/sortmerna"

# Nom de l'échantillon (à changer pour les prochains)
SAMPLE="MOCK_SAMPLE"

# NOUVEAU : Création du chemin vers le sous-dossier spécifique
SAMPLE_OUT_DIR="$OUTPUT_DIR/$SAMPLE"
mkdir -p $SAMPLE_OUT_DIR

R1="${INPUT_DIR}/${SAMPLE}_no_phix_R1.fastq.gz"
R2="${INPUT_DIR}/${SAMPLE}_no_phix_R2.fastq.gz"
REF_DB="${DB_DIR}/smr_v4.3_default_db.fasta"

echo "==================================================="
echo "🧬 Tri SortMeRNA TOTAL pour : $SAMPLE"
echo "==================================================="

# On nettoie le workdir pour être sûr que SortMeRNA repart à zéro
rm -rf $SAMPLE_OUT_DIR/workdir_${SAMPLE}

# Lancement de la bête (avec les nouveaux chemins pointant vers le sous-dossier) !
sortmerna \
    --ref $REF_DB \
    --reads $R1 \
    --reads $R2 \
    --workdir $SAMPLE_OUT_DIR/workdir_${SAMPLE} \
    --aligned $SAMPLE_OUT_DIR/${SAMPLE}_ribosome \
    --other $SAMPLE_OUT_DIR/${SAMPLE}_noribosome \
    --paired_in \
    --out2 \
    --fastx \
    --threads 14

echo "🗜️ Vérification et compression des résultats..."
# On ajoute une sécurité "silencieuse" au cas où SortMeRNA les a déjà compressés
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_ribosome_fwd.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_ribosome_rev.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_noribosome_fwd.fq 2>/dev/null || true
gzip -f $SAMPLE_OUT_DIR/${SAMPLE}_noribosome_rev.fq 2>/dev/null || true

echo "✅ NETTOYAGE TERMINÉ ET RANGÉ AVEC SUCCÈS DANS : $SAMPLE_OUT_DIR"
