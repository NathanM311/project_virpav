#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 15.1 : ASSEMBLAGE CIBLÉ (WITHOUT F2) DES READS VIRAUX
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

THREADS=14
MEM_SPADES=100  # GB

echo "===================================================================="
echo "🚀 DÉMARRAGE DE L'ASSEMBLAGE CIBLÉ (SPAdes) - WITHOUT F2"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

# Dossiers
MAP_DIR="$BASE_DIR/02_results/14.1_mapping_gvdb_withoutf2/$SAMPLE"
OUT_DIR="$BASE_DIR/02_results/15.1_targeted_assembly_withoutf2/$SAMPLE"
mkdir -p $OUT_DIR

# Fichiers
BAM_INPUT="$MAP_DIR/${SAMPLE}_GVDB_Q10_sorted.bam"
R1_VIRUS="$OUT_DIR/${SAMPLE}_virus_R1.fastq.gz"
R2_VIRUS="$OUT_DIR/${SAMPLE}_virus_R2.fastq.gz"

# === ACTIVATION POUR SAMTOOLS ===
echo "🔄 Chargement de l'environnement conda env_mapping (pour samtools)..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_mapping

# ------------------------------------------------------------------
# ÉTAPE 1 : EXTRACTION DES READS MAPPÉS
# ------------------------------------------------------------------
echo "📦 [1/3] Extraction des reads qui ont mappé sur GVDB..."

samtools sort -@ $THREADS -n $BAM_INPUT -o $OUT_DIR/tmp_mapped_sorted.bam

samtools fastq -@ $THREADS $OUT_DIR/tmp_mapped_sorted.bam \
    -1 $R1_VIRUS -2 $R2_VIRUS \
    -0 /dev/null -s /dev/null -n

# Suppression sécurisée
rm -f $OUT_DIR/tmp_mapped_sorted.bam

# === DÉSACTIVATION ===
conda deactivate

# ------------------------------------------------------------------
# 🛑 PROTECTION ANTI-CRASH (Vérification de la taille du fichier .gz)
# ------------------------------------------------------------------
FILE_SIZE=$(wc -c < "$R1_VIRUS")
if [ "$FILE_SIZE" -lt 100 ]; then
    echo "⚠️  AVERTISSEMENT : Trop peu de reads mappés sur GVDB."
    echo "⏭️  On saute l'assemblage SPAdes pour cet échantillon."
    touch "$OUT_DIR/no_reads_found.txt"
    exit 0
fi

# ------------------------------------------------------------------
# ÉTAPE 2 : ASSEMBLAGE AVEC SPADES (Mode --careful)
# ------------------------------------------------------------------
echo "🧩 [2/3] Assemblage SPAdes (Mode --careful) via env_spades..."

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
else
    echo "⚠️ L'assemblage n'a pas produit de scaffolds."
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(((ELAPSED % 3600) / 60))

echo "===================================================================="
echo "✅ TERMINÉ !"
echo "⏱️ Temps TOTAL : ${H}h ${M}m"
echo "===================================================================="