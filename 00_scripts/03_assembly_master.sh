#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 03 : ASSEMBLAGES MULTIPLES - MULTI-ENVIRONNEMENTS PROUVÉS
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

THREADS=14
MEM="100G"
MEM_SPADES=100

echo "===================================================================="
echo "🚀 DÉMARRAGE DU PIPELINE D'ASSEMBLAGE (Mode: Rigueur & Multi-Env)"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

INPUT_DIR="$BASE_DIR/02_results/03_sortmerna/$SAMPLE"
OUT_DIR="$BASE_DIR/02_results/04_assembly/$SAMPLE"

# Nettoyage de sécurité
rm -rf $OUT_DIR/noribosome_trinity $OUT_DIR/ribosome_trinity

# Fichiers originaux
R1_NORIBO_GZ="${INPUT_DIR}/${SAMPLE}_noribosome_fwd.fq.gz"
R2_NORIBO_GZ="${INPUT_DIR}/${SAMPLE}_noribosome_rev.fq.gz"
R1_RIBO_GZ="${INPUT_DIR}/${SAMPLE}_ribosome_fwd.fq.gz"
R2_RIBO_GZ="${INPUT_DIR}/${SAMPLE}_ribosome_rev.fq.gz"

# Fichiers temporaires DÉCOMPRESSÉS
TMP_DIR="$OUT_DIR/tmp_unzipped"
mkdir -p $TMP_DIR
R1_NORIBO_FQ="$TMP_DIR/noribo_R1.fq"
R2_NORIBO_FQ="$TMP_DIR/noribo_R2.fq"
R1_RIBO_FQ="$TMP_DIR/ribo_R1.fq"
R2_RIBO_FQ="$TMP_DIR/ribo_R2.fq"

echo "🗜️ [0/4] Préparation : Décompression des fichiers pour le vieux Trinity..."
zcat $R1_NORIBO_GZ > $R1_NORIBO_FQ
zcat $R2_NORIBO_GZ > $R2_NORIBO_FQ
zcat $R1_RIBO_GZ > $R1_RIBO_FQ
zcat $R2_RIBO_GZ > $R2_RIBO_FQ

# ------------------------------------------------------------------
# PARTIE 1 : NORIBOSOME (Virus + Algue)
# ------------------------------------------------------------------

echo "🧩 [1/4] rnaSPAdes via env_spades..."
conda run -n env_spades rnaspades.py -1 $R1_NORIBO_GZ -2 $R2_NORIBO_GZ -o $OUT_DIR/noribosome_rnaspades -t $THREADS -m $MEM_SPADES

echo "🧬 [2/4] Trinity via rnaseq (Fichiers décompressés)..."
conda run -n rnaseq Trinity --seqType fq --left $R1_NORIBO_FQ --right $R2_NORIBO_FQ \
        --CPU $THREADS --max_memory $MEM \
        --output $OUT_DIR/noribosome_trinity \
        --full_cleanup --min_contig_length 200

echo "🌸 [3/4] RNA-Bloom via env_rnabloom (Correctif manuel)..."
# On supprime l'ancien dossier foiré pour que Bloom ne tente pas de reprendre
rm -rf $OUT_DIR/noribosome_rnabloom

# On charge l'environnement proprement pour trouver le .jar
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_rnabloom
JAR_PATH=$(find $CONDA_PREFIX -name "rnabloom*.jar" | head -n 1)

# Lancement avec les 50 Go de RAM et le paramètre crucial -revcomp-right
java -Xmx50G -jar "$JAR_PATH" \
    -left $R1_NORIBO_GZ \
    -right $R2_NORIBO_GZ \
    -revcomp-right \
    -t $THREADS \
    -outdir $OUT_DIR/noribosome_rnabloom \
    -name "rnabloom"

conda deactivate

# ------------------------------------------------------------------
# PARTIE 2 : RIBOSOME 
# ------------------------------------------------------------------

echo "🌿 [4/4] Trinity via rnaseq (Ribosome)..."
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
echo "✅ TERMINÉ !"
echo "⏱️ Temps TOTAL : ${H}h ${M}m"
echo "===================================================================="