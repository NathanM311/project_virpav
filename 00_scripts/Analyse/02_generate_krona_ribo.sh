#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT Analyse 02 : KRONA PLOTS (ORIGINAL vs SANS CONTAMINANTS)
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
ANALYSE_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"

# Fichier TPM (Source d'abondance)
TPM_FILE="${BASE_DIR}/02_results/16_quantification_kallisto_all/${SAMPLE}/${SAMPLE}_abundance_ribo_TPM.tsv"

# Fichiers Taxonomiques - SET ORIGINAL
NUC_RAW="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_nuclear.tsv"
ORG_RAW="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_organelles.tsv"

# Fichiers Taxonomiques - SET CLEAN (Sans contaminants)
NUC_NC="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_nuclear_no_contaminants.tsv"
ORG_NC="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_organelles_no_contaminants.tsv"

# Sorties HTML
KRONA_HTML_RAW="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_original.html"
KRONA_HTML_NC="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_clean.html"

echo "===================================================================="
echo "🎡 GÉNÉRATION DES KRONA PLOTS (ORIGINAL & PROPRE) POUR : $SAMPLE"
echo "===================================================================="

if [ ! -f "$TPM_FILE" ]; then echo "❌ ERREUR : Fichier TPM absent (lancez Kallisto d'abord)."; exit 1; fi

# --- FONCTION BASH : PRÉPARATION DES DONNÉES KRONA ---
# Argument 1: Fichier Taxonomie | Arg 2: Fichier sortie Contigs | Arg 3: Fichier sortie TPM
prep_krona() {
    local tax_file=$1; local out_contigs=$2; local out_tpm=$3
    
    if [ ! -f "$tax_file" ]; then touch "$tax_file"; fi # Sécurité si vide

    # 1. Préparation Contigs
    awk -F'\t' 'NR>1 {print "1\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10}' "$tax_file" > "$out_contigs"
    
    # 2. Préparation TPM
    awk -F'\t' -v tpm_f="$TPM_FILE" '
        NR==FNR { tpm[$1]=$2; next }
        NR>1 { 
            val = (tpm[$1] ? tpm[$1] : 0);
            if (val > 0) print val"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10 
        }
    ' "$TPM_FILE" "$tax_file" > "$out_tpm"
}

# --- CHARGEMENT CONDA ---
echo "🔄 Activation de l'environnement Krona..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_krona

# ==========================================
# 1. KRONA : SET ORIGINAL
# ==========================================
echo "📊 1/2 : Génération du Krona ORIGINAL (Avec contaminants)..."
prep_krona "$NUC_RAW" "${ANALYSE_DIR}/tmp_nuc_raw_c.txt" "${ANALYSE_DIR}/tmp_nuc_raw_t.txt"
prep_krona "$ORG_RAW" "${ANALYSE_DIR}/tmp_org_raw_c.txt" "${ANALYSE_DIR}/tmp_org_raw_t.txt"

ktImportText \
    "${ANALYSE_DIR}/tmp_nuc_raw_t.txt,Noyau (TPM)" \
    "${ANALYSE_DIR}/tmp_nuc_raw_c.txt,Noyau (Contigs)" \
    "${ANALYSE_DIR}/tmp_org_raw_t.txt,Organites (TPM)" \
    "${ANALYSE_DIR}/tmp_org_raw_c.txt,Organites (Contigs)" \
    -o "$KRONA_HTML_RAW"

# ==========================================
# 2. KRONA : SET CLEAN (SANS CONTAMINANTS)
# ==========================================
echo "📊 2/2 : Génération du Krona DÉCONTAMINÉ (Propre)..."
if [ -f "$NUC_NC" ]; then
    prep_krona "$NUC_NC" "${ANALYSE_DIR}/tmp_nuc_nc_c.txt" "${ANALYSE_DIR}/tmp_nuc_nc_t.txt"
    prep_krona "$ORG_NC" "${ANALYSE_DIR}/tmp_org_nc_c.txt" "${ANALYSE_DIR}/tmp_org_nc_t.txt"

    ktImportText \
        "${ANALYSE_DIR}/tmp_nuc_nc_t.txt,Noyau (TPM)" \
        "${ANALYSE_DIR}/tmp_nuc_nc_c.txt,Noyau (Contigs)" \
        "${ANALYSE_DIR}/tmp_org_nc_t.txt,Organites (TPM)" \
        "${ANALYSE_DIR}/tmp_org_nc_c.txt,Organites (Contigs)" \
        -o "$KRONA_HTML_NC"
else
    echo "⚠️  Fichiers décontaminés introuvables. Lancez le script 04.1 avant."
fi

# --- NETTOYAGE ---
conda deactivate
rm -f "${ANALYSE_DIR}"/tmp_*.txt

echo "✅ Fichiers Krona générés avec succès !"
echo "   🧬 Version brute : $(basename $KRONA_HTML_RAW)"
echo "   🌊 Version pure  : $(basename $KRONA_HTML_NC)"
echo "===================================================================="