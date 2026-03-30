#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 09 : VALIDATION DIAMOND (Filtre Virus vs Hôte)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}
WORK_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
NR_DB="${BASE_DIR}/01_data/databases/nr.dmnd"

mkdir -p $WORK_DIR
cd $WORK_DIR

echo "🔄 Chargement de l'environnement conda..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_annot

echo "===================================================================="
echo "💎 1/2 : Lancement de DIAMOND BLASTP (Mode Ciblé sur les candidats)"
echo "===================================================================="
# On blast uniquement les ~3098 protéines qui ont matché avec les HMM
diamond blastp \
    --db $NR_DB \
    --query candidates_to_blast.faa \
    --out diamond_nr_validation.tsv \
    --outfmt 6 qseqid sseqid pident length evalue bitscore stitle \
    --threads 14 \
    --max-target-seqs 1 \
    --evalue 1e-5

echo "===================================================================="
echo "🧹 2/2 : Tri automatique (Virus vs Algues/Bactéries)"
echo "===================================================================="
# Extraction des lignes contenant des mots-clés viraux (insensible à la casse)
grep -iE "virus|phage|viridae" diamond_nr_validation.tsv > hits_CONFIRMED_VIRAL.tsv || true

# Extraction du reste (ce qui ne matche pas les mots-clés)
grep -ivE "virus|phage|viridae" diamond_nr_validation.tsv > hits_POTENTIAL_HOSTS.tsv || true

echo "===================================================================="
echo "📈 BILAN DU TRI :"
echo "🦠 Vrais hits viraux confirmés : $(wc -l < hits_CONFIRMED_VIRAL.tsv 2>/dev/null || echo 0)"
echo "🧬 Hits hôtes/algues écartés   : $(wc -l < hits_POTENTIAL_HOSTS.tsv 2>/dev/null || echo 0)"
echo "===================================================================="

conda deactivate

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
M=$((ELAPSED / 60))

echo "✅ SCRIPT 09 TERMINÉ EN ${M} minutes !"
