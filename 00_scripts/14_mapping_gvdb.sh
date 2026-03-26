#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 14 : MAPPING BWA-MEM DES READS SUR LA GIANT VIRUS DATABASE
# Utilisation : ./00_scripts/14_mapping_gvdb.sh <ECHANTILLON>
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
OUT_DIR="${BASE_DIR}/02_results/14_mapping_gvdb/${SAMPLE}"
mkdir -p $OUT_DIR

# ==================================================================
# ⚠️ ATTENTION : VÉRIFIE CES DEUX LIGNES POUR TES READS NETTOYÉS ⚠️
# Adapte le dossier et le nom exact de tes R1/R2 (ex: fp1, fp2, clean_R1...)
READS_DIR="${BASE_DIR}/02_results/02_phix_removed" 
R1="${READS_DIR}/${SAMPLE}_no_phix_R1.fastq.gz"
R2="${READS_DIR}/${SAMPLE}_no_phix_R2.fastq.gz"
# ==================================================================

# Dossiers GVDB
GVDB_DIR="${BASE_DIR}/01_data/GVDB_genomes"
GVDB_NUCL="${GVDB_DIR}/GVDB_nucl"
REF_FASTA="${GVDB_DIR}/GVDB_mega_reference.fasta"

echo "===================================================================="
echo "🎯 SCRIPT 14 : MAPPING BWA-MEM SUR GVDB POUR $SAMPLE"
echo "===================================================================="

# === NOUVEAU : ACTIVATION DE L'ENVIRONNEMENT ===
echo "🔄 Chargement de l'environnement conda env_mapping..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_mapping
# ===============================================

# 1. PRÉPARATION DE L'INDEX BWA (Se fait une seule fois)
if [ ! -f "${REF_FASTA}.bwt" ]; then
    echo "⚙️ 1/4 : Création du Méga-Génome (Fusion des 1382 virus)..."
    # On concatène tous les fichiers .fna ou .fasta du dossier GVDB_nucl
    cat ${GVDB_NUCL}/*.fna ${GVDB_NUCL}/*.fasta 2>/dev/null > $REF_FASTA
    
    echo "🏗️ Indexation BWA en cours (ça peut prendre quelques minutes)..."
    bwa index $REF_FASTA
else
    echo "✅ 1/4 : Index BWA déjà prêt !"
fi

# Fichiers de sortie
SAM_OUT="${OUT_DIR}/${SAMPLE}_GVDB.sam"
BAM_RAW="${OUT_DIR}/${SAMPLE}_GVDB_raw.bam"
BAM_Q10="${OUT_DIR}/${SAMPLE}_GVDB_Q10_sorted.bam"

# 2. MAPPING BWA-MEM
echo "🚀 2/4 : Mapping BWA-MEM des reads (Le chalut est lancé)..."
bwa mem -t 14 $REF_FASTA $R1 $R2 > $SAM_OUT

# 3. CONVERSION, TRI ET FILTRAGE Q10
echo "📦 3/4 : Conversion SAM -> BAM et Filtrage stricte (MAPQ >= 10)..."
# On convertit en BAM pour gagner de la place
samtools view -@ 14 -bS $SAM_OUT > $BAM_RAW
# On filtre Q10 (-q 10) et on trie par coordonnées (sort)
samtools view -@ 14 -b -q 10 -f 2 $BAM_RAW | samtools sort -@ 14 -o $BAM_Q10
# On indexe le BAM final pour les logiciels de visualisation (comme IGV)
samtools index $BAM_Q10

# 4. STATISTIQUES ET COMPTAGE
echo "📊 4/4 : Comptage des abondances virales..."
TSV_OUT="${OUT_DIR}/${SAMPLE}_viral_abundance.tsv"
# idxstats donne : "Nom_Génome  Taille_Génome  Reads_Mappés  Reads_Non_Mappés"
# On ne garde que ceux qui ont plus de 0 reads, et on trie par nombre de reads
samtools idxstats $BAM_Q10 | awk '$3 > 0 {print $0}' | sort -k3,3nr > $TSV_OUT

# Nettoyage des gros fichiers temporaires
rm $SAM_OUT $BAM_RAW

# === NOUVEAU : DÉSACTIVATION ===
conda deactivate
# ===============================

echo "===================================================================="
echo "✅ MAPPING TERMINÉ !"

echo "===================================================================="
echo "✅ MAPPING TERMINÉ !"
echo "📁 Tes fichiers de résultats sont ici : $OUT_DIR"
echo "🏆 TOP 15 DES VIRUS GÉANTS LES PLUS ACTIFS :"
echo -e "GENOME_VIRAL\tTAILLE\tNB_READS\tNB_READS_ORPHELINS"
head -n 15 $TSV_OUT | column -t
echo "===================================================================="