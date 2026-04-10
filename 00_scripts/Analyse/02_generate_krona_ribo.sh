#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT Analyse 02 : GÉNÉRATION DU KRONA PLOT INTERACTIF
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
ANALYSE_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"
UNIFIED_FILE="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_detailed.tsv"
KRONA_INPUT="${ANALYSE_DIR}/${SAMPLE}_krona_input.txt"
KRONA_HTML="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona.html"

echo "===================================================================="
echo "🎡 GÉNÉRATION DU KRONA PLOT POUR : $SAMPLE"
echo "===================================================================="

if [ ! -f "$UNIFIED_FILE" ]; then
    echo "❌ ERREUR : Le fichier unifié est introuvable. Lancez l'Analyse 01 d'abord."
    exit 1
fi

# 1. Préparation du format Krona (Count \t Level1 \t Level2 ...)
# Chaque ligne de notre fichier est un contig, donc le compte est "1"
# Colonnes du fichier unifié : 4 (Domain), 5 (Phylum), 6 (Class), 7 (Order), 8 (Family), 9 (Genus), 10 (Species)
awk -F'\t' 'NR>1 {print "1\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10}' "$UNIFIED_FILE" > "$KRONA_INPUT"

# 2. Génération du HTML avec Krona
# On utilise l'environnement conda dédié
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_krona

ktImportText "$KRONA_INPUT" -o "$KRONA_HTML"

conda deactivate

# 3. Nettoyage du fichier temporaire
rm "$KRONA_INPUT"

echo "✅ Krona Plot généré : $KRONA_HTML"
echo "===================================================================="