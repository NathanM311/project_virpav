#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 11 : INTÉGRATION FINALE (CheckV + DIAMOND)
# Objectif    : Croiser les contigs ultra-purs avec leur annotation
# Utilisation : ./00_scripts/11_final_viral_integration.sh <NOM_ECHANTILLON>
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}

echo "===================================================================="
echo "🧬 CROISEMENT FINAL POUR L'ÉCHANTILLON : $SAMPLE"
echo "===================================================================="

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
CHECKV_DIR="${BASE_DIR}/02_results/10_checkv/${SAMPLE}/checkv_results"
DIAMOND_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/11_final_integration/${SAMPLE}"

mkdir -p $OUT_DIR

CHECKV_SUMMARY="${CHECKV_DIR}/quality_summary.tsv"
DIAMOND_TSV="${DIAMOND_DIR}/diamond_nr_validation.tsv"

# 1. Sécurité : Vérification de l'existence des fichiers
if [ ! -f "$CHECKV_SUMMARY" ] || [ ! -f "$DIAMOND_TSV" ]; then
    echo "❌ ERREUR : Fichiers CheckV ou DIAMOND introuvables pour $SAMPLE."
    exit 1
fi

# 2. Extraction des IDs "Ultra-Purs" depuis CheckV
echo "🧹 1/2 : Extraction des transcrits validés par CheckV (Gènes Viraux > 0, Hôte = 0)..."
awk -F'\t' 'NR>1 && $6 > 0 && $7 == 0 {print $1}' $CHECKV_SUMMARY > ${OUT_DIR}/pure_contig_ids.txt

NB_PURS=$(wc -l < ${OUT_DIR}/pure_contig_ids.txt)
echo "📊 Nombre de transcrits ultra-purs isolés : $NB_PURS"

# 3. Croisement intelligent avec DIAMOND
echo "🔍 2/2 : Croisement avec les annotations DIAMOND NR..."

# On crée l'en-tête du fichier final
echo -e "PROTEIN_ID\tCONTIG_ID\tPIDENT\tLENGTH\tEVALUE\tBITSCORE\tANNOTATION" > ${OUT_DIR}/final_annotated_viruses.tsv

# On boucle sur chaque contig pur pour retrouver sa protéine correspondante dans DIAMOND
# On utilise une regex stricte (^ID[._]) pour éviter que NODE_1 ne matche NODE_10
while read -r contig_id; do
    grep "^${contig_id}[._]" $DIAMOND_TSV | awk -v cid="$contig_id" -F'\t' '{print $1"\t"cid"\t"$3"%\t"$4"\t"$5"\t"$6"\t"$7}' >> ${OUT_DIR}/final_annotated_viruses.tsv
done < ${OUT_DIR}/pure_contig_ids.txt

echo "===================================================================="
echo "✅ SCRIPT 11 TERMINÉ !"
echo "📁 Ton fichier final pour ton article est prêt ici :"
echo "   ${OUT_DIR}/final_annotated_viruses.tsv"
echo "===================================================================="