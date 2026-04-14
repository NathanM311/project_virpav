#!/bin/bash
set -e
# ------------------------------------------------------------------
# ANALYSE 01 : RÉSOLUTION DES CONFLITS TAXONOMIQUES (VERSION PARALLÈLE)
# Rôle : Créer deux sets de tables unifiées (Original vs No Contaminants)
#        pour comparaison ultérieure.
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TAX_DIR="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"
mkdir -p "$OUT_DIR"

# --- 1. DÉFINITION DES ENTRÉES ---
# Set Original
PR2_RAW="${TAX_DIR}/${SAMPLE}_vs_PR2_CLEAN.tsv"
SSU_RAW="${TAX_DIR}/${SAMPLE}_vs_SILVA_SSU_CLEAN.tsv"
LSU_RAW="${TAX_DIR}/${SAMPLE}_vs_SILVA_LSU_CLEAN.tsv"

# Set Décontaminé (CORRIGÉ avec _CLEAN_)
PR2_NC="${TAX_DIR}/${SAMPLE}_vs_PR2_CLEAN_no_contaminants.tsv"
SSU_NC="${TAX_DIR}/${SAMPLE}_vs_SILVA_SSU_CLEAN_no_contaminants.tsv"
LSU_NC="${TAX_DIR}/${SAMPLE}_vs_SILVA_LSU_CLEAN_no_contaminants.tsv"

# --- 2. DÉFINITION DES SORTIES ---
NUC_RAW="${OUT_DIR}/${SAMPLE}_unified_microbiome_nuclear.tsv"
ORG_RAW="${OUT_DIR}/${SAMPLE}_unified_microbiome_organelles.tsv"
NUC_NC="${OUT_DIR}/${SAMPLE}_unified_microbiome_nuclear_no_contaminants.tsv"
ORG_NC="${OUT_DIR}/${SAMPLE}_unified_microbiome_organelles_no_contaminants.tsv"

# Seuils
MIN_LEN=300
MIN_ID=95
HEADER="Contig_ID\tDatabase\tRef_ID\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\tIdentity\tLength\tE-value\tBitscore"

# --- FONCTION DE TRAITEMENT (AWK) ---
# $1: PR2, $2: SSU, $3: LSU, $4: Sortie_NUC, $5: Sortie_ORG
process_tax() {
    local f_pr2=$1; local f_ssu=$2; local f_lsu=$3; local out_nuc=$4; local out_org=$5
    local tmp_nuc="${out_nuc}.tmp"; local tmp_org="${out_org}.tmp"

    awk -F'\t' -v m_len="$MIN_LEN" -v m_id="$MIN_ID" -v t_nuc="$tmp_nuc" -v t_org="$tmp_org" '
    BEGIN { OFS="\t" }
    FNR==1 { next }

    # PR2
    FILENAME == ARGV[1] {
        contig=$1; ref_id=$2; id=$15; len=$16; ev=$17; bit=$18;
        gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
        is_org = ($4 ~ /plastid/ || $4 ~ /mitochondrion/ || $4 ~ /Chloroplast/) ? 1 : 0;
        if ((len+0) >= m_len && (id+0) >= m_id) {
            db[contig]="PR2"; refseq[contig]=ref_id; dom[contig]=$6; phy[contig]=$8; cla[contig]=$10;
            ord[contig]=$11; fam[contig]=$12; gen[contig]=$13; spe[contig]=$14;
            ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit; flag[contig]=is_org;
        }
    }
    # SILVA
    FILENAME == ARGV[2] || FILENAME == ARGV[3] {
        contig=$1; ref_id=$2; id=$3; len=$4; ev=$5; bit=$6; tax=$7;
        gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
        sub(/^[^ ]+ +/, "", tax);
        is_org = (tax ~ /Chloroplast/ || tax ~ /Mitochondria/) ? 1 : 0;
        if ((len+0) >= m_len && (id+0) >= m_id) {
            split(tax, a, ";"); current_db = (FILENAME ~ /LSU/) ? "SILVA_LSU" : "SILVA_SSU";
            if (!(contig in score) || (bit+0) > (score[contig]+0)) {
                db[contig]=current_db; refseq[contig]=ref_id; dom[contig]=a[1]; phy[contig]=a[2]; cla[contig]=a[3];
                ord[contig]=a[4]; fam[contig]=a[5]; gen[contig]=a[6]; spe[contig]=a[7];
                ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit; flag[contig]=is_org;
            }
        }
    }
    END {
        for (c in db) {
            l = c"\t"db[c]"\t"refseq[c]"\t"dom[c]"\t"phy[c]"\t"cla[c]"\t"ord[c]"\t"fam[c]"\t"gen[c]"\t"spe[c]"\t"ident[c]"\t"leng[c]"\t"evalue[c]"\t"score[c]
            if (flag[c] == 1) print l > t_org; else print l > t_nuc
        }
    }' "$f_pr2" "$f_ssu" "$f_lsu"

    # Tri final
    echo -e "$HEADER" > "$out_nuc"
    if [ -f "$tmp_nuc" ]; then sort -t$'\t' -k14,14nr "$tmp_nuc" >> "$out_nuc"; rm "$tmp_nuc"; fi
    echo -e "$HEADER" > "$out_org"
    if [ -f "$tmp_org" ]; then sort -t$'\t' -k14,14nr "$tmp_org" >> "$out_org"; rm "$tmp_org"; fi
}

echo "===================================================================="
echo "🚀 EXÉCUTION DE L'ANALYSE PARALLÈLE : $SAMPLE"
echo "===================================================================="

# --- ÉTAPE 1 : GÉNÉRATION DU SET ORIGINAL ---
echo "📝 1/2 : Unification des données ORIGINALES..."
process_tax "$PR2_RAW" "$SSU_RAW" "$LSU_RAW" "$NUC_RAW" "$ORG_RAW"

# --- ÉTAPE 2 : GÉNÉRATION DU SET DÉCONTAMINÉ ---
echo "📝 2/2 : Unification des données DÉCONTAMINÉES..."
if [ -f "$PR2_NC" ]; then
    process_tax "$PR2_NC" "$SSU_NC" "$LSU_NC" "$NUC_NC" "$ORG_NC"
else
    echo "⚠️  Skip : Fichiers décontaminés introuvables. Lancez le script 04.1 avant."
fi

echo "✅ ANALYSE TERMINÉE !"
echo "📂 Fichiers originaux : $(basename $NUC_RAW) & $(basename $ORG_RAW)"
echo "📂 Fichiers propres    : $(basename $NUC_NC) & $(basename $ORG_NC)"
echo "===================================================================="