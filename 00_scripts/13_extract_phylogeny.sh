#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 13 : EXTRACTION DES SÉQUENCES POUR LA PHYLOGÉNIE (CORRIGÉ)
# Utilisation : ./00_scripts/13_extract_phylogeny.sh <ECHANTILLON> "<MOT_CLE>"
# Exemple     : ./00_scripts/13_extract_phylogeny.sh 10-21D-AC16 "capsid"
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}
KEYWORD=${2:-"capsid"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TSV_FILE="${BASE_DIR}/02_results/12_verification_hmm/${SAMPLE}/2_best_hits_translated.tsv"

# 👉 LA CORRECTION EST LÀ : On pointe vers le dossier 09 où se trouvent tes .pep
PEP_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/13_phylogeny/${SAMPLE}"

mkdir -p $OUT_DIR

echo "===================================================================="
echo "🧬 SCRIPT 13 : EXTRACTION PHYLOGÉNÉTIQUE POUR '$KEYWORD'"
echo "===================================================================="

if [ ! -f "$TSV_FILE" ]; then
    echo "❌ ERREUR : Le tableau traduit du Script 12 est introuvable."
    exit 1
fi

if [ ! -f "${PEP_DIR}/PROTEINS_TD.pep" ]; then
    echo "❌ ERREUR : Le fichier PROTEINS_TD.pep est introuvable dans $PEP_DIR"
    exit 1
fi

# 1. Recherche des identifiants correspondant au mot-clé
LISTE_IDS="${OUT_DIR}/ids_to_extract.txt"
grep -i "$KEYWORD" $TSV_FILE | awk -F'\t' '{print $2}' > $LISTE_IDS

NB_HITS=$(wc -l < $LISTE_IDS)
if [ "$NB_HITS" -eq 0 ]; then
    echo "⚠️ Aucun résultat trouvé pour le mot-clé '$KEYWORD'."
    rm $LISTE_IDS
    exit 0
fi

echo "🔍 $NB_HITS protéine(s) trouvée(s) contenant '$KEYWORD' !"
echo "💾 Extraction depuis PROTEINS_TD.pep et PROTEINS_RESCUE.pep..."

OUT_FASTA="${OUT_DIR}/phylogeny_${KEYWORD}_${SAMPLE}.fasta"

# 2. On fusionne temporairement les deux fichiers de protéines pour tout fouiller
cat ${PEP_DIR}/PROTEINS_TD.pep ${PEP_DIR}/PROTEINS_RESCUE.pep 2>/dev/null > ${OUT_DIR}/temp_all_proteins.pep

# 3. Extraction de la séquence
awk '
    NR==FNR { wanted[$1]; next } 
    /^>/ { 
        id=$1; sub(/^>/, "", id); 
        keep = (id in wanted)     
    } 
    keep { print $0 }             
' $LISTE_IDS ${OUT_DIR}/temp_all_proteins.pep > $OUT_FASTA

# Nettoyage
rm ${OUT_DIR}/temp_all_proteins.pep

echo "===================================================================="
echo "✅ EXTRACTION TERMINÉE !"
echo "📁 Tes séquences prêtes à être alignées sont ici :"
echo "   $OUT_FASTA"
echo "--------------------------------------------------------------------"
echo "APERÇU DES 4 PREMIÈRES LIGNES :"
head -n 4 $OUT_FASTA
echo "===================================================================="