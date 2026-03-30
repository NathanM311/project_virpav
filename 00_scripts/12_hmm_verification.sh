#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 12 : VÉRIFICATION HMM (TOUS LES HITS + MEILLEURS TRADUITS)
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
HMM_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
INT_DIR="${BASE_DIR}/02_results/11_final_integration/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/12_verification_hmm/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/hmm"

PURE_LIST="${INT_DIR}/pure_contig_ids.txt"
mkdir -p $OUT_DIR

if [ ! -f "$PURE_LIST" ]; then
    echo "❌ ERREUR : Le fichier pure_contig_ids.txt est introuvable."
    exit 1
fi

echo "===================================================================="
echo "🕵️‍♂️ 1/3 EXTRACTION DE TOUS LES HITS HMM POUR $SAMPLE"
echo "===================================================================="
# Fichiers temporaires propres
cat ${HMM_DIR}/GVDB_hits_TD.tsv ${HMM_DIR}/GVDB_hits_RESCUE.tsv 2>/dev/null | grep -v "^#" > ${OUT_DIR}/temp_GVDB.txt
cat ${HMM_DIR}/VOGDB_hits_TD.tsv ${HMM_DIR}/VOGDB_hits_RESCUE.tsv 2>/dev/null | grep -v "^#" > ${OUT_DIR}/temp_VOGDB.txt

# --- FICHIER 1 : TOUS LES HITS (La sauvegarde brute) ---
OUT_ALL="${OUT_DIR}/1_all_hmm_hits_raw.tsv"
echo -e "CONTIG_ID\tPROTEINE_ID\tBASE_HMM\tCODE_HMM\tE-VALUE" > $OUT_ALL

while read -r contig_id; do
    grep "^${contig_id}[._]" ${OUT_DIR}/temp_GVDB.txt | awk -v cid="$contig_id" 'BEGIN {OFS="\t"} {print cid, $1, "GVDB", $3, $5}' >> $OUT_ALL
    grep "^${contig_id}[._]" ${OUT_DIR}/temp_VOGDB.txt | awk -v cid="$contig_id" 'BEGIN {OFS="\t"} {print cid, $1, "VOGDB", $3, $5}' >> $OUT_ALL
done < $PURE_LIST

# Nettoyage des doublons exacts du fichier brut
sort -u $OUT_ALL -o $OUT_ALL

echo "✨ 2/3 FILTRAGE DU MEILLEUR HIT PAR PROTÉINE"
OUT_BEST_RAW="${OUT_DIR}/temp_best_raw.tsv"
head -n 1 $OUT_ALL > $OUT_BEST_RAW
tail -n +2 $OUT_ALL | sort -k2,2 -k5,5g | awk -F'\t' '!seen[$2]++' >> $OUT_BEST_RAW

echo "===================================================================="
echo "📖 3/3 TRADUCTION DES CODES EN FONCTIONS BIOLOGIQUES"
echo "===================================================================="

DICT_TEMP="${OUT_DIR}/temp_dictionary.txt"
> $DICT_TEMP

# Traduction VOGDB : Format "VOG0001 \t Fonction..."
awk -F'\t' '{print $1"\t"$5}' ${DB_DIR}/vog.annotations.tsv >> $DICT_TEMP

# Traduction GVDB : On enlève le 'm' pour que GVOGm0003 devienne GVOG0003
awk -F'\t' 'NR>1 {code=$1; gsub(/m/, "", code); print code"\t"$5}' ${DB_DIR}/GVOGs/gvog.complete.annot.tsv >> $DICT_TEMP

# --- FICHIER 2 : LE RÉSULTAT FINAL TRADUIT (Pour l'article) ---
FINAL_TSV="${OUT_DIR}/2_best_hits_translated.tsv"
echo -e "CONTIG_ID\tPROTEINE_ID\tBASE_HMM\tCODE_HMM\tFONCTION_BIOLOGIQUE\tE-VALUE" > $FINAL_TSV

awk -F'\t' '
    NR==FNR { dict[$1] = $2; next }
    FNR > 1 {
        code = $4
        # Nettoyage du code : on enlève ".trim" (ex: GVOG10059.trim -> GVOG10059)
        clean_code = code
        gsub(/\.trim$/, "", clean_code)
        
        fonction = dict[clean_code]
        if (fonction == "") fonction = "Fonction_Inconnue"
        print $1"\t"$2"\t"$3"\t"clean_code"\t"fonction"\t"$5
    }
' $DICT_TEMP $OUT_BEST_RAW >> $FINAL_TSV

# Nettoyage de l'espace de travail (on supprime tous les fichiers qui commencent par temp_)
rm ${OUT_DIR}/temp_*

echo "✅ TERMINÉ !"
echo "📁 Tes deux fichiers sont précieusement gardés ici :"
echo "   1. Brut (Tous les hits) : $OUT_ALL"
echo "   2. Traduit (Article)    : $FINAL_TSV"
echo "--------------------------------------------------------------------"
echo "🏆 APERÇU DES RÉSULTATS TRADUITS (TOP 15) :"
head -n 16 $FINAL_TSV | column -t -s $'\t'
echo "===================================================================="