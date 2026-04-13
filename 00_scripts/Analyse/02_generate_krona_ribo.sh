#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT Analyse 02 : KRONA PLOT DOUBLE (CONTIGS vs TPM KALLISTO)
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Chemins des fichiers (MISE À JOUR DU CHEMIN TPM VERS KALLISTO)
ANALYSE_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"
UNIFIED_FILE="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_detailed.tsv"
TPM_FILE="${BASE_DIR}/02_results/16_quantification_kallisto_all/${SAMPLE}/${SAMPLE}_abundance_ribo_TPM.tsv"

# Fichiers temporaires pour Krona
KRONA_IN_CONTIGS="${ANALYSE_DIR}/krona_in_contigs.txt"
KRONA_IN_TPM="${ANALYSE_DIR}/krona_in_tpm.txt"
KRONA_HTML="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_multi.html"

echo "===================================================================="
echo "🎡 GÉNÉRATION DU KRONA PLOT DOUBLE POUR : $SAMPLE"
echo "===================================================================="

# Vérifications
if [ ! -f "$UNIFIED_FILE" ]; then echo "❌ Fichier taxonomie absent."; exit 1; fi
if [ ! -f "$TPM_FILE" ]; then echo "❌ Fichier TPM absent (lancez le script Kallisto d'abord)."; exit 1; fi

# --- 1. Préparation du dataset : NOMBRE DE CONTIGS ---
echo "📝 Préparation des données : Nombre de Contigs..."
awk -F'\t' 'NR>1 {print "1\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10}' "$UNIFIED_FILE" > "$KRONA_IN_CONTIGS"

# --- 2. Préparation du dataset : ABONDANCE TPM ---
echo "📝 Préparation des données : Abondance TPM..."
# On utilise awk pour joindre les deux fichiers sur l'ID du contig ($1)
awk -F'\t' '
    NR==FNR { tpm[$1]=$2; next }
    NR>1 { 
        val = (tpm[$1] ? tpm[$1] : 0);
        print val"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10 
    }
' "$TPM_FILE" "$UNIFIED_FILE" > "$KRONA_IN_TPM"

# --- 3. Génération du Krona (avec 2 sources) ---
echo "🔄 Activation de Krona et génération du HTML..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_krona

# ktImportText accepte plusieurs fichiers. 
# On utilise -n pour nommer les onglets dans le graphique.
ktImportText \
    "$KRONA_IN_CONTIGS,Nombre de Contigs" \
    "$KRONA_IN_TPM,Abondance (TPM)" \
    -o "$KRONA_HTML"

conda deactivate

# Nettoyage
rm "$KRONA_IN_CONTIGS" "$KRONA_IN_TPM"

echo "✅ Krona Plot Double généré : $KRONA_HTML"
echo "💡 Note : Utilisez le menu en haut à droite du graphique pour changer de vue."
echo "===================================================================="