#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 15 : ASSEMBLAGE CIBLÉ (TARGETED ASSEMBLY) DES READS VIRAUX
# BUT : Reconstruire le protogénome à partir des reads mappés sur GVDB
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

THREADS=14
MEM_SPADES=100  # GB

echo "===================================================================="
echo "🚀 DÉMARRAGE DE L'ASSEMBLAGE CIBLÉ (SPAdes)"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

# Dossiers
MAP_DIR="$BASE_DIR/02_results/14_mapping_gvdb/$SAMPLE"
OUT_DIR="$BASE_DIR/02_results/15_targeted_assembly/$SAMPLE"
mkdir -p $OUT_DIR

# Fichiers
BAM_INPUT="$MAP_DIR/${SAMPLE}_GVDB_Q10_sorted.bam"
R1_VIRUS="$OUT_DIR/${SAMPLE}_virus_R1.fastq.gz"
R2_VIRUS="$OUT_DIR/${SAMPLE}_virus_R2.fastq.gz"

# === NOUVEAU : ACTIVATION POUR SAMTOOLS ===
echo "🔄 Chargement de l'environnement conda env_mapping (pour samtools)..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_mapping
# ==========================================

# ------------------------------------------------------------------
# ÉTAPE 1 : EXTRACTION DES READS MAPPÉS

# ------------------------------------------------------------------
# ÉTAPE 1 : EXTRACTION DES READS MAPPÉS
# ------------------------------------------------------------------
echo "📦 [1/3] Extraction des reads qui ont mappé sur GVDB..."

# -F 4 : On ne garde que les reads mappés
# -n   : On trie par nom pour que samtools fastq garde les paires ensemble
samtools sort -@ $THREADS -n $BAM_INPUT -o $OUT_DIR/tmp_mapped_sorted.bam

samtools fastq -@ $THREADS $OUT_DIR/tmp_mapped_sorted.bam \
    -1 $R1_VIRUS -2 $R2_VIRUS \
    -0 /dev/null -s /dev/null -n

rm $OUT_DIR/tmp_mapped_sorted.bam

rm $OUT_DIR/tmp_mapped_sorted.bam

# === NOUVEAU : DÉSACTIVATION ===
conda deactivate
# ===============================

# ------------------------------------------------------------------
# ÉTAPE 2 : ASSEMBLAGE AVEC SPADES (Mode --careful)

# ------------------------------------------------------------------
# ÉTAPE 2 : ASSEMBLAGE AVEC SPADES (Mode --careful)
# ------------------------------------------------------------------
echo "🧩 [2/3] Assemblage SPAdes (Mode --careful) via env_spades..."

# Note : On utilise spades.py (DNA) plutôt que rnaspades car on cherche 
# à reconstruire un génome/protogénome viral à partir de reads d'ADN.
# --careful réduit les erreurs de substitution et les indels.
conda run -n env_spades spades.py \
    -1 $R1_VIRUS -2 $R2_VIRUS \
    -o $OUT_DIR/spades_assembly \
    -t $THREADS -m $MEM_SPADES \
    --careful

# ------------------------------------------------------------------
# ÉTAPE 3 : ANALYSE DES RÉSULTATS
# ------------------------------------------------------------------
echo "📊 [3/3] Analyse rapide des contigs générés..."

if [ -f "$OUT_DIR/spades_assembly/scaffolds.fasta" ]; then
    NUM_CONTIGS=$(grep -c ">" $OUT_DIR/spades_assembly/scaffolds.fasta)
    echo "✅ Assemblage terminé !"
    echo "🧬 Nombre de contigs viraux potentiels : $NUM_CONTIGS"
    echo "📁 Fichier final : $OUT_DIR/spades_assembly/scaffolds.fasta"
else
    echo "⚠️ L'assemblage n'a pas produit de scaffolds. Les reads étaient peut-être trop peu diversifiés."
fi

# Fin du chrono
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(((ELAPSED % 3600) / 60))

echo "===================================================================="
echo "✅ TERMINÉ !"
echo "⏱️ Temps TOTAL : ${H}h ${M}m"
echo "===================================================================="