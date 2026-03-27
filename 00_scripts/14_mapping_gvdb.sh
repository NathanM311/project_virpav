#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 14 : MAPPING BWA-MEM DES READS SUR LA GIANT VIRUS DATABASE
# Utilisation : ./00_scripts/14_mapping_gvdb.sh <ECHANTILLON>
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
OUT_DIR="${BASE_DIR}/02_results/14_mapping_gvdb/${SAMPLE}"
mkdir -p $OUT_DIR

# ==================================================================
# CHEMINS DYNAMIQUES (Gère les sous-dossiers et les extensions)
# ==================================================================
READS_DIR="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"
# L'utilisation de ls avec joker permet d'attraper .fq.gz ou .fastq.gz
R1=$(ls ${READS_DIR}/${SAMPLE}_no_phix_R1.f*q.gz)
R2=$(ls ${READS_DIR}/${SAMPLE}_no_phix_R2.f*q.gz)

# Dossiers GVDB
GVDB_DIR="${BASE_DIR}/01_data/GVDB_genomes"
GVDB_NUCL="${GVDB_DIR}/GVDB_nucl"
REF_FASTA="${GVDB_DIR}/GVDB_mega_reference.fasta"

echo "===================================================================="
echo "🎯 SCRIPT 14 : MAPPING BWA-MEM SUR GVDB POUR $SAMPLE"
echo "===================================================================="

# === ACTIVATION DE L'ENVIRONNEMENT ===
echo "🔄 Chargement de l'environnement conda env_mapping..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_mapping
# ===============================================

# 1. PRÉPARATION DE L'INDEX BWA (Se fait une seule fois)
if [ ! -f "${REF_FASTA}.bwt" ]; then
    echo "⚙️ 1/4 : Création du Méga-Génome (Fusion des 1382 virus)..."
    cat ${GVDB_NUCL}/*.fna ${GVDB_NUCL}/*.fasta 2>/dev/null > $REF_FASTA
    
    echo "🏗️ Indexation BWA en cours (ça peut prendre quelques minutes)..."
    bwa index $REF_FASTA
else
    echo "✅ 1/4 : Index BWA déjà prêt !"
fi

# ==================================================================
# ASTUCE ANTI-COUPURE RÉSEAU : UTILISATION DU DISQUE LOCAL (/tmp)
# ==================================================================
LOCAL_TMP="/tmp/${SAMPLE}_mapping"
mkdir -p $LOCAL_TMP

# 2. MAPPING BWA-MEM ET CONVERSION DIRECTE
echo "🚀 2/4 : Mapping BWA-MEM et conversion BAM à la volée (Sur disque local)..."
# Le pipe '|' évite d'écrire le SAM sur le disque
bwa mem -t 14 $REF_FASTA $R1 $R2 | samtools view -@ 14 -bS - > $LOCAL_TMP/raw.bam

# 3. TRI ET FILTRAGE Q10 (En local)
echo "📦 3/4 : Filtrage strict (MAPQ >= 10)..."
samtools view -@ 14 -b -q 10 -f 2 $LOCAL_TMP/raw.bam | samtools sort -@ 14 -o $LOCAL_TMP/${SAMPLE}_GVDB_Q10_sorted.bam
samtools index $LOCAL_TMP/${SAMPLE}_GVDB_Q10_sorted.bam

# 4. STATISTIQUES ET RAPATRIEMENT
echo "📊 4/4 : Comptage et transfert vers MERSEA..."
TSV_OUT="${OUT_DIR}/${SAMPLE}_viral_abundance.tsv"
samtools idxstats $LOCAL_TMP/${SAMPLE}_GVDB_Q10_sorted.bam | awk '$3 > 0 {print $0}' | sort -k3,3nr > $TSV_OUT

# On rapatrie le fichier final propre sur le disque réseau
mv $LOCAL_TMP/${SAMPLE}_GVDB_Q10_sorted.bam* $OUT_DIR/

# Nettoyage du disque local
rm -rf $LOCAL_TMP
# ==================================================================

# === DÉSACTIVATION ===
conda deactivate
# ===============================

echo "===================================================================="
echo "✅ MAPPING TERMINÉ !"
echo "📁 Tes fichiers de résultats sont ici : $OUT_DIR"
echo "🏆 TOP 15 DES VIRUS GÉANTS LES PLUS ACTIFS :"
echo -e "GENOME_VIRAL\tTAILLE\tNB_READS\tNB_READS_ORPHELINS"
head -n 15 $TSV_OUT | column -t
echo "===================================================================="