#!/bin/bash
set -e
# ------------------------------------------------------------------
# ANALYSE 01 : RÉSOLUTION DES CONFLITS TAXONOMIQUES (PR2 vs SSU vs LSU)
# Rôle : Créer une table de communauté unifiée avec REF_ID, TAXONOMIE et E-VALUE
#        (Sépare le Nucléaire et les Organites)
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

# NOUVEAU : Deux fichiers finaux
NUC_TSV="${OUT_DIR}/${SAMPLE}_unified_microbiome_nuclear.tsv"
ORG_TSV="${OUT_DIR}/${SAMPLE}_unified_microbiome_organelles.tsv"

# Fichiers temporaires pour le tri
TEMP_NUC="${OUT_DIR}/temp_nuc.tsv"
TEMP_ORG="${OUT_DIR}/temp_org.tsv"

# Seuils
MIN_LEN=300
MIN_ID=95

echo "===================================================================="
echo "🧬 BATAILLE TAXONOMIQUE ET EXTRACTION DÉTAILLÉE POUR : $SAMPLE"
echo "===================================================================="

# Initialisation des en-têtes pour les DEUX fichiers
HEADER="Contig_ID\tDatabase\tRef_ID\tDomain\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\tIdentity\tLength\tE-value\tBitscore"
echo -e "$HEADER" > "$NUC_TSV"
echo -e "$HEADER" > "$ORG_TSV"

for f in "$PR2_FILE" "$SILVA_SSU_FILE" "$SILVA_LSU_FILE"; do
    if [ ! -f "$f" ]; then touch "$f"; fi
done

# NOUVEAU : On passe les chemins des fichiers temporaires à awk
awk -F'\t' -v m_len="$MIN_LEN" -v m_id="$MIN_ID" -v t_nuc="$TEMP_NUC" -v t_org="$TEMP_ORG" '
BEGIN { OFS="\t" }

# On saute la première ligne (en-têtes) de chaque fichier
FNR==1 { next }

# --- 1. FORMAT PR2 ---
FILENAME == ARGV[1] {
    contig=$1; ref_id=$2; id=$15; len=$16; ev=$17; bit=$18;
    gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
    
    # On détecte si c est un organite
    is_org = ($4 ~ /plastid/ || $4 ~ /mitochondrion/ || $4 ~ /Chloroplast/) ? 1 : 0;
    
    # NOUVEAU : On garde tout (is_org n est plus un critère d exclusion)
    if ((len+0) >= m_len && (id+0) >= m_id) {
        db[contig]="PR2"; refseq[contig]=ref_id; dom[contig]=$6; phy[contig]=$8; cla[contig]=$10;
        ord[contig]=$11; fam[contig]=$12; gen[contig]=$13; spe[contig]=$14;
        ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit;
        organelle_flag[contig]=is_org; # On mémorise si c est un organite
    }
}

# --- 2 & 3. FORMAT SILVA (SSU & LSU) ---
FILENAME == ARGV[2] || FILENAME == ARGV[3] {
    contig=$1; ref_id=$2; id=$3; len=$4; ev=$5; bit=$6; taxonomy=$7;
    gsub(/,/, ".", id); gsub(/,/, ".", ev); gsub(/,/, ".", bit);
    
    # Suppression de l ID de référence caché dans la taxonomie SILVA
    sub(/^[^ ]+ +/, "", taxonomy);
    
    # On détecte si c est un organite
    is_org = (taxonomy ~ /Chloroplast/ || taxonomy ~ /Mitochondria/) ? 1 : 0;
    
    # NOUVEAU : On garde tout (is_org n est plus un critère d exclusion)
    if ((len+0) >= m_len && (id+0) >= m_id) {
        
        split(taxonomy, arr, ";");
        cur_dom = arr[1]; cur_phy = arr[2]; cur_cla = arr[3];
        cur_ord = arr[4]; cur_fam = arr[5]; cur_gen = arr[6]; cur_spe = arr[7];
        
        current_db = (FILENAME ~ /LSU/) ? "SILVA_LSU" : "SILVA_SSU";

        # Arbitrage (celui qui a le plus haut Bitscore gagne la place)
        if (!(contig in score) || (bit+0) > (score[contig]+0)) {
            db[contig]=current_db; refseq[contig]=ref_id; dom[contig]=cur_dom; phy[contig]=cur_phy; cla[contig]=cur_cla;
            ord[contig]=cur_ord; fam[contig]=cur_fam; gen[contig]=cur_gen; spe[contig]=cur_spe;
            ident[contig]=id; leng[contig]=len; evalue[contig]=ev; score[contig]=bit;
            organelle_flag[contig]=is_org; # On mémorise si c est un organite
        }
    }
}

END {
    # On imprime dans le bon fichier temporaire selon le flag organite
    for (c in db) {
        line = c"\t"db[c]"\t"refseq[c]"\t"dom[c]"\t"phy[c]"\t"cla[c]"\t"ord[c]"\t"fam[c]"\t"gen[c]"\t"spe[c]"\t"ident[c]"\t"leng[c]"\t"evalue[c]"\t"score[c]
        
        if (organelle_flag[c] == 1) {
            print line > t_org
        } else {
            print line > t_nuc
        }
    }
}' "$PR2_FILE" "$SILVA_SSU_FILE" "$SILVA_LSU_FILE"

# Tri des résultats finaux par Bitscore décroissant
if [ -f "$TEMP_NUC" ]; then
    sort -t$'\t' -k14,14nr "$TEMP_NUC" >> "$NUC_TSV"
    rm "$TEMP_NUC"
fi

if [ -f "$TEMP_ORG" ]; then
    sort -t$'\t' -k14,14nr "$TEMP_ORG" >> "$ORG_TSV"
    rm "$TEMP_ORG"
fi

echo "✅ Fusion et séparation terminées avec succès !"
echo "📊 Contigs Nucléaires : $(tail -n +2 "$NUC_TSV" | wc -l)"
echo "📊 Contigs Organites  : $(tail -n +2 "$ORG_TSV" | wc -l)"
echo "📂 Fichiers générés dans : $OUT_DIR"
echo "===================================================================="