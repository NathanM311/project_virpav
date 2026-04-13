#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT 16 : QUANTIFICATION DOUBLE AVEC KALLISTO (Le Plan B robuste)
# DESTINATION : 02_results/16_quantification_kallisto_all
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# Nouveau dossier pour Kallisto
QUANT_BASE="${BASE_DIR}/02_results/16_quantification_kallisto_all/${SAMPLE}"
mkdir -p "$QUANT_BASE"

# --- ENVIRONNEMENT ---
source $HOME/miniconda3/etc/profile.d/conda.sh
if ! conda info --envs | grep -q "env_kallisto"; then
    echo "🏗️ Création de l'environnement Kallisto..."
    conda create -n env_kallisto -c bioconda kallisto -y
fi
conda activate env_kallisto

# Fonction pour lancer Kallisto
run_kallisto() {
    local assembly=$1
    local r1=$2
    local r2=$3
    local out_dir="${QUANT_BASE}/$4"
    local tpm_file="${QUANT_BASE}/$5"
    local index_file="${out_dir}/transcripts.idx"

    if [ ! -f "$assembly" ]; then 
        echo "⚠️ Skip : $(basename "$assembly") introuvable"
        return
    fi
    mkdir -p "$out_dir"

    echo "--- 🦦 Quantification sur : $(basename "$assembly") ---"
    
    # 1. Indexation
    if [ ! -f "$index_file" ]; then
        echo "📂 Création de l'index Kallisto..."
        kallisto index -i "$index_file" "$assembly"
    fi

    # 2. Quantification
    if [ ! -f "${out_dir}/abundance.tsv" ]; then
        echo "🧮 Calcul des TPM..."
        # -t 12 pour utiliser 12 cœurs
        kallisto quant -i "$index_file" -o "$out_dir" -t 12 "$r1" "$r2"
    fi

    # 3. Extraction du TPM (Chez Kallisto, Colonne 1: ID, Colonne 5: TPM)
    awk -F'\t' 'NR>1 {print $1 "\t" $5}' "${out_dir}/abundance.tsv" > "$tpm_file"
    echo "✅ TPM générés : $(basename "$tpm_file")"
}

echo "===================================================================="
echo "🚀 DÉMARRAGE QUANTIFICATION KALLISTO : $SAMPLE"
echo "📂 Sortie : $QUANT_BASE"
echo "===================================================================="

# --- 1. QUANTIFICATION DU MICROBIOME (Ribosomal) ---
RIBO_ASM="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
RIBO_R1="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_fwd.fq.gz"
RIBO_R2="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_rev.fq.gz"

run_kallisto "$RIBO_ASM" "$RIBO_R1" "$RIBO_R2" "kallisto_ribo" "${SAMPLE}_abundance_ribo_TPM.tsv"

# --- 2. QUANTIFICATION GLOBALE (Clustered - Virus & Co) ---
CLUSTER_ASM="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
NORIBO_R1="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_noribosome_fwd.fq.gz"
NORIBO_R2="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_noribosome_rev.fq.gz"

run_kallisto "$CLUSTER_ASM" "$NORIBO_R1" "$NORIBO_R2" "kallisto_clustered" "${SAMPLE}_abundance_clustered_TPM.tsv"

conda deactivate
echo "🏁 [FIN] Toutes les quantifications sont dans : $QUANT_BASE"
echo "===================================================================="