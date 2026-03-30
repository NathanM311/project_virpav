#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 07 : ANNOTATION DES CANDIDATS VIRAUX VIRSORTER2 (DIAMOND)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

# Chemins
IN_FASTA="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}/final-viral-combined.fa"
OUT_DIR="${BASE_DIR}/02_results/08_annotation_virsorter2/${SAMPLE}"

# Bases de données DIAMOND (dans ton dossier V2)
DB_VIRAL="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V2_PROPRE/01_data/databases/refseq_viral.dmnd"
DB_NR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V2_PROPRE/01_data/databases/nr.dmnd"

mkdir -p $OUT_DIR

echo "🔄 Chargement de env_diamond..."
source $HOME/miniconda3/etc/profile.d/conda.sh
if ! conda info --envs | grep -q "env_diamond"; then
    conda create -n env_diamond -c bioconda diamond -y
fi
conda activate env_diamond

echo "===================================================================="
echo "💎 Lancement de DIAMOND BLASTx..."
echo "===================================================================="

# 1. Blast contre RefSeq Viral
echo "🔬 [1/2] Blast contre RefSeq Viral..."
diamond blastx --query $IN_FASTA \
               --db $DB_VIRAL \
               --out $OUT_DIR/${SAMPLE}_vs_refseq_viral.tsv \
               --outfmt 6 qseqid sseqid pident length evalue bitscore stitle \
               --threads 14 \
               --max-target-seqs 5 \
               --evalue 1e-5

# 2. Blast contre NR (Base généraliste complète)
echo "🔬 [2/2] Blast contre NR..."
diamond blastx --query $IN_FASTA \
               --db $DB_NR \
               --out $OUT_DIR/${SAMPLE}_vs_nr.tsv \
               --outfmt 6 qseqid sseqid pident length evalue bitscore stitle \
               --threads 14 \
               --max-target-seqs 5 \
               --evalue 1e-5

conda deactivate

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
M=$((ELAPSED / 60))

echo "===================================================================="
echo "✅ ANNOTATION TERMINÉE EN ${M} minutes !"
echo "📊 Résultats dans : $OUT_DIR/"
echo "===================================================================="
