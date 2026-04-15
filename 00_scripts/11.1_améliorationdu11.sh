#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 11 : INTÉGRATION FINALE (CheckV + DIAMOND NCBI + HMM)
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}
echo "===================================================================="
echo "🧬 CROISEMENT MULTI-PREUVES POUR : $SAMPLE"
echo "===================================================================="

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
CHECKV_DIR="${BASE_DIR}/02_results/10_checkv/${SAMPLE}/checkv_results"
DIAMOND_TSV="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}/diamond_nr_validation.tsv"
HMM_TSV="${BASE_DIR}/02_results/12_verification_hmm/${SAMPLE}/2_best_hits_translated.tsv"
OUT_DIR="${BASE_DIR}/02_results/11_final_integration/${SAMPLE}"

mkdir -p "$OUT_DIR"
FINAL_TSV="${OUT_DIR}/final_annotated_viruses.tsv"

# 1. Extraction des IDs candidats (On assouplit CheckV pour ne pas perdre les NCLDV)
# On garde les contigs où CheckV a trouvé au moins 1 gène viral, MÊME S'IL Y A DES GÈNES D'HÔTES (AMGs)
awk -F'\t' 'NR>1 && $6 > 0 {print $1}' "$CHECKV_DIR/quality_summary.tsv" > "${OUT_DIR}/pure_contig_ids.txt"

NB_PURS=$(wc -l < "${OUT_DIR}/pure_contig_ids.txt")
echo "📊 Nombre de contigs structuraux validés par CheckV : $NB_PURS"

# 2. Création de l'en-tête du Super-Tableau
echo -e "PROTEIN_ID\tCONTIG_ID\tNCBI_ANNOTATION\tNCBI_PIDENT\tHMM_DB\tHMM_CODE\tHMM_FONCTION" > "$FINAL_TSV"

# 3. Le Super-Croisement : Pour chaque protéine du fichier NCBI, on cherche si elle a un match HMM
echo "🔍 Fusion des bases de données NCBI et HMM..."

# On charge le fichier HMM dans un dictionnaire Awk, puis on lit le fichier DIAMOND
awk -F'\t' -v list="${OUT_DIR}/pure_contig_ids.txt" '
    # Bloc 1 : Charger la liste des contigs validés par CheckV
    NR==FNR { valid_contigs[$1]; next }
    
    # Bloc 2 : Charger le dictionnaire HMM (Fichier 12)
    ARGIND==2 && FNR>1 { 
        # Prot_ID -> DB | Code | Fonction
        hmm_dict[$2] = $3 "\t" $4 "\t" $5
        next
    }
    
    # Bloc 3 : Traiter le fichier DIAMOND NCBI (Fichier 09)
    ARGIND==3 {
        prot_id = $1
        # On extrait le nom du contig depuis la protéine
        contig_id = prot_id
        sub(/\.[pP][0-9]+$/, "", contig_id) # Retire les suffixes TransDecoder
        sub(/_[0-9]+$/, "", contig_id)      # Retire les suffixes getorf
        
        # Si le contig a été validé par CheckV
        if (contig_id in valid_contigs) {
            ncbi_annot = $7
            ncbi_pident = $3"%"
            
            # Si on a une annotation HMM pour cette protéine
            if (prot_id in hmm_dict) {
                hmm_info = hmm_dict[prot_id]
            } else {
                hmm_info = "AUCUN_MATCH_HMM\t-\t-"
            }
            
            print prot_id "\t" contig_id "\t" ncbi_annot "\t" ncbi_pident "\t" hmm_info
        }
    }
' "${OUT_DIR}/pure_contig_ids.txt" "$HMM_TSV" "$DIAMOND_TSV" >> "$FINAL_TSV"

echo "✅ SCRIPT 11 TERMINÉ !"
echo "📁 Ton tableau ultime est ici : $FINAL_TSV"