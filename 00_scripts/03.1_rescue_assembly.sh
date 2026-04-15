#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 03.1 : RESCUE ASSEMBLY (Reprise après crash)
# BUT : Relancer UNIQUEMENT l'assemblage Ribosomique (Étape 4/4)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Par défaut, on cible la cellule qui a crashé
SAMPLE=${1:-"2-4N-AC15"} 

THREADS=14
MEM="100G"
MEM_SPADES=100

echo "===================================================================="
echo "🚑 DÉMARRAGE DU RESCUE ASSEMBLY (Ribosome Uniquement)"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

INPUT_DIR="$BASE_DIR/02_results/03_sortmerna/$SAMPLE"
OUT_DIR="$BASE_DIR/02_results/04_assembly/$SAMPLE"

# 1. Nettoyage de sécurité (uniquement pour le ribosome, on ne touche pas au reste !)
rm -rf $OUT_DIR/ribosome_trinity

# Fichiers originaux
R1_RIBO_GZ="${INPUT_DIR}/${SAMPLE}_ribosome_fwd.fq.gz"
R2_RIBO_GZ="${INPUT_DIR}/${SAMPLE}_ribosome_rev.fq.gz"

# 2. Fichiers temporaires DÉCOMPRESSÉS (pour Trinity)
TMP_DIR="$OUT_DIR/tmp_unzipped_rescue"
mkdir -p $TMP_DIR
R1_RIBO_FQ="$TMP_DIR/ribo_R1.fq"
R2_RIBO_FQ="$TMP_DIR/ribo_R2.fq"

echo "🗜️ [1/2] Préparation : Décompression des fichiers ribosomiques..."
zcat $R1_RIBO_GZ > $R1_RIBO_FQ
zcat $R2_RIBO_GZ > $R2_RIBO_FQ

# ------------------------------------------------------------------
# PARTIE 2 : RIBOSOME (La fameuse étape qui a été interrompue)
# ------------------------------------------------------------------
echo "🌿 [2/2] Assemblage Ribosome (Trinity seul)..."

# [OPTION FUTUR] : Lancement de rnaSPAdes (Pour obtenir un 28S non fragmenté)
# conda run -n env_spades rnaspades.py -1 $R1_RIBO_GZ -2 $R2_RIBO_GZ -o $OUT_DIR/ribosome_rnaspades -t $THREADS -m $MEM_SPADES

echo "   -> Lancement de Trinity..."
conda run -n rnaseq Trinity --seqType fq --left $R1_RIBO_FQ --right $R2_RIBO_FQ \
        --CPU $THREADS --max_memory $MEM \
        --output $OUT_DIR/ribosome_trinity \
        --full_cleanup --min_contig_length 200

# ------------------------------------------------------------------
# NETTOYAGE
# ------------------------------------------------------------------
echo "🧹 Nettoyage des fichiers temporaires..."
rm -rf $TMP_DIR

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(((ELAPSED % 3600) / 60))

echo "===================================================================="
echo "✅ RESCUE TERMINÉ AVEC SUCCÈS !"
echo "⏱️ Temps de reprise : ${H}h ${M}m"
echo "===================================================================="