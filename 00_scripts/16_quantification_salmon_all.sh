#!/bin/bash
set -e

# ------------------------------------------------------------------
# SCRIPT 16.1 : QUANTIFICATION DOUBLE (RIBO + CLUSTERED)
# DESTINATION : 02_results/16_quantification_salmon_all
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"

# --- NOUVELLE STRUCTURE DE DOSSIERS ---
QUANT_BASE="${BASE_DIR}/02_results/16_quantification_salmon_all/${SAMPLE}"
mkdir -p "$QUANT_BASE"

# --- ENVIRONNEMENT ---
source $HOME/miniconda3/etc/profile.d/conda.sh
if ! conda info --envs | grep -q "env_quantif"; then
    echo "🏗️ Création de l'environnement salmon..."
    conda create -n env_quantif -c bioconda salmon -y
fi
conda activate env_quantif

# Fonction pour lancer Salmon
# Usage: run_salmon <assembly_file> <reads_R1> <reads_R2> <output_subdir> <tpm_final_name>
run_salmon() {
    local assembly=$1
    local r1=$2
    local r2=$3
    local out_dir="${QUANT_BASE}/$4"
    local tpm_file="${QUANT_BASE}/$5"

    if [ ! -f "$assembly" ]; then 
        echo "⚠️ Skip : $(basename "$assembly") introuvable"
        return
    fi

    echo "--- 🐟 Quantification sur : $(basename "$assembly") ---"
    
    # 1. Indexation
    if [ ! -d "${out_dir}/index" ]; then
        echo "📂 Création de l'index dans $out_dir..."
        salmon index -t "$assembly" -i "${out_dir}/index" --keepDuplicates
    fi

    # 2. Quantification
    if [ ! -f "${out_dir}/quant.sf" ]; then
        echo "🧮 Calcul des TPM..."
        salmon quant -i "${out_dir}/index" -l A -1 "$r1" -2 "$r2" \
            -p 12 --validateMappings -o "$out_dir"
    fi

    # 3. Extraction du TPM (Colonne 1: Name, Colonne 4: TPM)
    awk -F'\t' 'NR>1 {print $1 "\t" $4}' "${out_dir}/quant.sf" > "$tpm_file"
    echo "✅ TPM générés : $(basename "$tpm_file")"
}

echo "===================================================================="
echo "🚀 DÉMARRAGE QUANTIFICATION SALMON : $SAMPLE"
echo "📂 Sortie : $QUANT_BASE"
echo "===================================================================="

# --- 1. QUANTIFICATION DU MICROBIOME (Ribosomal) ---
RIBO_ASM="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
RIBO_R1="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_fwd.fq.gz"
RIBO_R2="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_rev.fq.gz"

run_salmon "$RIBO_ASM" "$RIBO_R1" "$RIBO_R2" "salmon_ribo" "${SAMPLE}_abundance_ribo_TPM.tsv"

# --- 2. QUANTIFICATION GLOBALE (Clustered - Virus & Co) ---
CLUSTER_ASM="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
NORIBO_R1="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_noribosome_fwd.fq.gz"
NORIBO_R2="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_noribosome_rev.fq.gz"

run_salmon "$CLUSTER_ASM" "$NORIBO_R1" "$NORIBO_R2" "salmon_clustered" "${SAMPLE}_abundance_clustered_TPM.tsv"

conda deactivate
echo "🏁 [FIN] Toutes les quantifications sont dans : $QUANT_BASE"