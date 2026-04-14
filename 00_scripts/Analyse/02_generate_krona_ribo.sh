#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT Analyse 02 : KRONA PLOT MULTIPLE (NOYAU vs ORGANITES x CONTIGS vs TPM)
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# NOUVEAUX Chemins des fichiers taxonomiques
ANALYSE_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"
NUC_FILE="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_nuclear.tsv"
ORG_FILE="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_organelles.tsv"
TPM_FILE="${BASE_DIR}/02_results/16_quantification_kallisto_all/${SAMPLE}/${SAMPLE}_abundance_ribo_TPM.tsv"

# Fichiers temporaires pour Krona
KRONA_NUC_CONTIGS="${ANALYSE_DIR}/krona_nuc_contigs.txt"
KRONA_NUC_TPM="${ANALYSE_DIR}/krona_nuc_tpm.txt"
KRONA_ORG_CONTIGS="${ANALYSE_DIR}/krona_org_contigs.txt"
KRONA_ORG_TPM="${ANALYSE_DIR}/krona_org_tpm.txt"

KRONA_HTML="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_multi.html"

echo "===================================================================="
echo "🎡 GÉNÉRATION DU KRONA PLOT (4 VUES) POUR : $SAMPLE"
echo "===================================================================="

# Vérifications
if [ ! -f "$TPM_FILE" ]; then echo "❌ Fichier TPM absent (lancez Kallisto d'abord)."; exit 1; fi
if [ ! -f "$NUC_FILE" ]; then echo "⚠️ Attention: Fichier nucléaire absent."; touch "$NUC_FILE"; fi
if [ ! -f "$ORG_FILE" ]; then echo "⚠️ Attention: Fichier organites absent."; touch "$ORG_FILE"; fi

# --- 1. Préparation du dataset : NOYAU ---
echo "📝 Préparation des données Nucléaires..."
awk -F'\t' 'NR>1 {print "1\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10}' "$NUC_FILE" > "$KRONA_NUC_CONTIGS"

awk -F'\t' '
    NR==FNR { tpm[$1]=$2; next }
    NR>1 { 
        val = (tpm[$1] ? tpm[$1] : 0);
        if (val > 0) print val"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10 
    }
' "$TPM_FILE" "$NUC_FILE" > "$KRONA_NUC_TPM"

# --- 2. Préparation du dataset : ORGANITES ---
echo "📝 Préparation des données Organites (Chloroplastes/Mitochondries)..."
awk -F'\t' 'NR>1 {print "1\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10}' "$ORG_FILE" > "$KRONA_ORG_CONTIGS"

awk -F'\t' '
    NR==FNR { tpm[$1]=$2; next }
    NR>1 { 
        val = (tpm[$1] ? tpm[$1] : 0);
        if (val > 0) print val"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10 
    }
' "$TPM_FILE" "$ORG_FILE" > "$KRONA_ORG_TPM"


# --- 3. Génération du Krona (avec 4 sources) ---
echo "🔄 Activation de Krona et génération du HTML..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_krona

# ktImportText va créer un menu déroulant en haut à droite avec ces 4 options
ktImportText \
    "$KRONA_NUC_TPM,Noyau (Abondance TPM)" \
    "$KRONA_NUC_CONTIGS,Noyau (Diversité Contigs)" \
    "$KRONA_ORG_TPM,Organites (Abondance TPM)" \
    "$KRONA_ORG_CONTIGS,Organites (Diversité Contigs)" \
    -o "$KRONA_HTML"

conda deactivate

# Nettoyage
rm -f "$KRONA_NUC_CONTIGS" "$KRONA_NUC_TPM" "$KRONA_ORG_CONTIGS" "$KRONA_ORG_TPM"

echo "✅ Krona Plot 4-en-1 généré : $KRONA_HTML"
echo "💡 Note : Ouvrez le HTML dans un navigateur web. Le menu en haut à gauche permet de basculer entre le noyau et les organites !"
echo "===================================================================="