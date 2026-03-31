#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 06 : DÉCOUVERTE VIRALE AVEC VIRSORTER2 (Groupes complets)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

# Chemins
IN_FASTA="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
OUT_DIR="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/virsorter2_db"

# Si le dossier existe déjà (ex: run précédent), on le vide pour éviter le crash de VirSorter2
if [ -d "$OUT_DIR" ]; then
    echo "⚠️ Nettoyage du dossier VirSorter2 existant pour $SAMPLE..."
    rm -rf "${OUT_DIR:?}"/*
    rm -rf "${OUT_DIR}"/.snakemake 2>/dev/null
else
    mkdir -p "$OUT_DIR"
fi

echo "🔄 Chargement de env_virsorter2..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_virsorter2

echo "===================================================================="
echo "🦠 Lancement de VirSorter2 (NCLDV, RNA, Phages, ssDNA, Virophages)..."
echo "===================================================================="

# Ajout de 'lavidaviridae' pour les virophages
virsorter run -w $OUT_DIR \
              -i $IN_FASTA \
              --db-dir $DB_DIR \
              --include-groups "NCLDV,RNA,dsDNAphage,ssDNA,lavidaviridae" \
              --min-score 0.5 \
              --keep-original-seq \
              --jobs 14 \
              all

conda deactivate

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
M=$((ELAPSED / 60))

echo "===================================================================="
echo "✅ VIRSORTER2 TERMINÉ EN ${M} minutes !"
echo "📊 Résultats dans : $OUT_DIR/"
echo "===================================================================="
