#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 04 : TAXONOMIE DES RIBOSOMES (BLASTn - PR2 + SILVA SSU/LSU)
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

# Chemins
QUERY_FASTA="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
OUT_DIR="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}"

# Dossiers des bases de données (séparés selon ton arborescence)
DB_DIR_PR2="${BASE_DIR}/01_data/ribosomes/PR2"
DB_DIR_SILVA="${BASE_DIR}/01_data/ribosomes/Silva"

mkdir -p $OUT_DIR

echo "===================================================================="
echo "🚀 DÉMARRAGE DE L'ANNOTATION TAXONOMIQUE MULTI-BASES"
echo "🦠 Échantillon : $SAMPLE"
echo "===================================================================="

echo "🔄 Chargement de env_blast..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_blast

# ------------------------------------------------------------------
# 1. BLAST contre PR2 (Référence Eucaryotes / Chloroplastes)
# ------------------------------------------------------------------
echo "🔬 [1/4] Lancement de BLASTn contre PR2 v5.1.1..."
blastn -query $QUERY_FASTA \
       -db $DB_DIR_PR2/PR2_v5.1.1_db \
       -out $OUT_DIR/${SAMPLE}_vs_PR2.tsv \
       -evalue 1e-5 \
       -num_threads 14 \
       -max_target_seqs 5 \
       -outfmt "6 qseqid sseqid pident length evalue bitscore stitle"

# ------------------------------------------------------------------
# 2. BLAST contre SILVA SSU (16S/18S Exhaustif)
# ------------------------------------------------------------------
echo "🔬 [2/4] Lancement de BLASTn contre SILVA SSU..."
blastn -query $QUERY_FASTA \
       -db $DB_DIR_SILVA/SILVA_SSU_db \
       -out $OUT_DIR/${SAMPLE}_vs_SILVA_SSU.tsv \
       -evalue 1e-5 \
       -num_threads 14 \
       -max_target_seqs 5 \
       -outfmt "6 qseqid sseqid pident length evalue bitscore stitle"

# ------------------------------------------------------------------
# 3. BLAST contre SILVA LSU (23S/28S)
# ------------------------------------------------------------------
echo "🔬 [3/4] Lancement de BLASTn contre SILVA LSU..."
blastn -query $QUERY_FASTA \
       -db $DB_DIR_SILVA/SILVA_LSU_db \
       -out $OUT_DIR/${SAMPLE}_vs_SILVA_LSU.tsv \
       -evalue 1e-5 \
       -num_threads 14 \
       -max_target_seqs 5 \
       -outfmt "6 qseqid sseqid pident length evalue bitscore stitle"

# ------------------------------------------------------------------
# 4. NETTOYAGE DES DONNÉES (Top Hit, Filtres, En-têtes)
# ------------------------------------------------------------------
echo "🧹 [4/4] Nettoyage et formatage des résultats..."

# Paramètres de filtrage
MIN_ID=90
MIN_LEN=200

# Fichiers à traiter
FILES=(
    "${SAMPLE}_vs_PR2.tsv"
    "${SAMPLE}_vs_SILVA_SSU.tsv"
    "${SAMPLE}_vs_SILVA_LSU.tsv"
)

for FILE in "${FILES[@]}"; do
    INPUT="$OUT_DIR/$FILE"
    OUTPUT="$OUT_DIR/${FILE/.tsv/_CLEAN.tsv}" # Ajoute _CLEAN au nom du fichier
    
    if [ -s "$INPUT" ]; then 
        if [[ "$FILE" == *"PR2"* ]]; then
            # Traitement spécifique pour PR2 (Découpage des |)
            echo "  -> Formatage PR2 pour $FILE..."
            awk -F'\t' -v OFS='\t' -v id="$MIN_ID" -v len="$MIN_LEN" '
            BEGIN {print "Contig_ID\tRef_ID\tGene\tOrganelle\tStrain\tDomain\tSupergroup\tDivision\tSubdivision\tClass\tOrder\tFamily\tGenus\tSpecies\tIdentity_pct\tAlign_Length\tE-value\tBitscore"}
            !vus[$1]++ && $3 >= id && $4 >= len {
                split($2, tax, "|")
                print $1, tax[1], tax[2], tax[3], tax[4], tax[5], tax[6], tax[7], tax[8], tax[9], tax[10], tax[11], tax[12], tax[13], $3, $4, $5, $6
            }
            ' "$INPUT" > "$OUTPUT"
            
        else
            # Traitement standard pour SILVA (Taxonomie en colonne 7)
            echo "  -> Formatage SILVA pour $FILE..."
            awk -F'\t' -v OFS='\t' -v id="$MIN_ID" -v len="$MIN_LEN" '
            BEGIN {print "Contig_ID\tRef_ID\tIdentity_pct\tAlign_Length\tE-value\tBitscore\tTaxonomy"}
            !vus[$1]++ && $3 >= id && $4 >= len {
                gsub(/\|/, ";", $7)
                print $1, $2, $3, $4, $5, $6, $7
            }
            ' "$INPUT" > "$OUTPUT"
        fi
        
    else
        echo "  ⚠️ Fichier $FILE vide ou introuvable, étape ignorée."
    fi
done

# ------------------------------------------------------------------
# FIN DU SCRIPT
# ------------------------------------------------------------------
conda deactivate

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
H=$((ELAPSED / 3600))
M=$(((ELAPSED % 3600) / 60))

echo "===================================================================="
echo "✅ TOUS LES BLAST ET LE NETTOYAGE SONT TERMINÉS EN ${H}h ${M}m !"
echo "📊 Résultats propres disponibles dans : $OUT_DIR/"
echo "===================================================================="