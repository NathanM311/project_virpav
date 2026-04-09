#!/bin/bash
set -e
# ------------------------------------------------------------------
# ANALYSE 01 : RÉSOLUTION DES CONFLITS TAXONOMIQUES (PR2 vs SSU vs LSU)
# Rôle : Créer une table de communauté unifiée avec REF_ID, TAXONOMIE et E-VALUE
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Entrées
PR2_FILE="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_PR2_CLEAN.tsv"
SILVA_SSU_FILE="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_SILVA_SSU_CLEAN.tsv"
SILVA_LSU_FILE="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_SILVA_LSU_CLEAN.tsv"

# Sorties
OUT_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"
mkdir -p "$OUT_DIR"
UNIFIED_TSV="${OUT_DIR}/${SAMPLE}_unified_microbiome_detailed.tsv"
TEMP_TSV="${OUT_DIR}/temp_unified.tsv"

# Seuils
MIN_LEN=300
MIN_ID=95

echo "===================================================================="
echo "🧬 BATAILLE TAXONOMIQUE ET EXTRACTION DÉTAILLÉE POUR : $SAMPLE"
echo "===================================================================="

# Initialisation de l'en-tête (Ajout de la colonne Ref_ID en 3ème position)
echo -e "Contig_ID\tDatabase\tRef_ID\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\tIdentity\tLength\tE-value\tBitscore" > "$UNIFIED_TSV"

for f in "$PR2_FILE" "$SILVA_SSU_FILE" "$SILVA_LSU_FILE"; do
    if [ ! -f "$f" ]; then touch "$f"; fi
done

awk -F'\t' -v m_len="$MIN_LEN" -v m_id="$MIN_ID" '
BEGIN { OFS="\t" }

# On saute la première ligne (en-têtes) de chaque fichier
FNR==1 { next }

# --- 1. FORMAT PR2 ---
FILENAME == ARGV[1] {
    contig=$1; ref_id=$2; id=$15; len=$16; ev=$17; bit=$18;
    gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
    
    is_org = ($4 ~ /plastid/ || $4 ~ /mitochondrion/ || $4 ~ /Chloroplast/) ? 1 : 0;
    
    if ((len+0) >= m_len && (id+0) >= m_id && is_org == 0) {
        db[contig]="PR2"; refseq[contig]=ref_id; dom[contig]=$6; phy[contig]=$8; cla[contig]=$10;
        ord[contig]=$11; fam[contig]=$12; gen[contig]=$13; spe[contig]=$14;
        ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit;
    }
}

# --- 2 & 3. FORMAT SILVA (SSU & LSU) ---
FILENAME == ARGV[2] || FILENAME == ARGV[3] {
    contig=$1; ref_id=$2; id=$3; len=$4; ev=$5; bit=$6; taxonomy=$7;
    gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
    
    # Suppression de l ID de référence caché dans la taxonomie SILVA
    sub(/^[^ ]+ +/, "", taxonomy);
    
    is_org = (taxonomy ~ /Chloroplast/ || taxonomy ~ /Mitochondria/) ? 1 : 0;
    
    if ((len+0) >= m_len && (id+0) >= m_id && is_org == 0) {
        
        # On découpe les 7 niveaux de SILVA
        split(taxonomy, arr, ";");
        cur_dom = arr[1]; cur_phy = arr[2]; cur_cla = arr[3];
        cur_ord = arr[4]; cur_fam = arr[5]; cur_gen = arr[6]; cur_spe = arr[7];
        
        current_db = (FILENAME ~ /LSU/) ? "SILVA_LSU" : "SILVA_SSU";

        # Arbitrage (celui qui a le plus haut Bitscore gagne la place)
        if (!(contig in score) || (bit+0) > (score[contig]+0)) {
            db[contig]=current_db; refseq[contig]=ref_id; dom[contig]=cur_dom; phy[contig]=cur_phy; cla[contig]=cur_cla;
            ord[contig]=cur_ord; fam[contig]=cur_fam; gen[contig]=cur_gen; spe[contig]=cur_spe;
            ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit;
        }
    }
}

END {
    # On imprime tout dans le bon ordre
    for (c in db) {
        print c, db[c], refseq[c], dom[c], phy[c], cla[c], ord[c], fam[c], gen[c], spe[c], ident[c], leng[c], evalue[c], score[c]
    }
}' "$PR2_FILE" "$SILVA_SSU_FILE" "$SILVA_LSU_FILE" > "$TEMP_TSV"

# Tri du résultat final par Bitscore décroissant (qui est maintenant la colonne 14)
sort -t$'\t' -k14,14nr "$TEMP_TSV" >> "$UNIFIED_TSV"
rm "$TEMP_TSV"

echo "✅ Fusion terminée avec succès ! (Ref_ID inclus)"
echo "📊 Total contigs validés : $(tail -n +2 "$UNIFIED_TSV" | wc -l)"
echo "📄 Fichier généré : $UNIFIED_TSV"
echo "===================================================================="