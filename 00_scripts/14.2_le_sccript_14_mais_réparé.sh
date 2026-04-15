#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 14 (CORRIGÉ) : MAPPING BWA-MEM SUR LA GIANT VIRUS DATABASE
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
OUT_DIR="${BASE_DIR}/02_results/14_mapping_gvdb/${SAMPLE}"
mkdir -p "$OUT_DIR"

echo "===================================================================="
echo "🎯 SCRIPT 14 : MAPPING BWA-MEM SUR GVDB POUR $SAMPLE"
echo "===================================================================="

# ------------------------------------------------------------------
# 1. RÉCUPÉRATION SÉCURISÉE DES READS (Correction du bug 'ls')
# ------------------------------------------------------------------
READS_DIR="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"

# On cherche le fichier R1 (qu'il finisse par .fq.gz ou .fastq.gz)
R1=$(find "$READS_DIR" -name "${SAMPLE}_no_phix_R1.*q.gz" | head -n 1)
R2=$(find "$READS_DIR" -name "${SAMPLE}_no_phix_R2.*q.gz" | head -n 1)

if [ -z "$R1" ] || [ -z "$R2" ]; then
    echo "❌ ERREUR : Fichiers R1 ou R2 introuvables dans $READS_DIR"
    exit 1
fi

echo "🔍 Reads détectés :"
echo "   R1 : $R1"
echo "   R2 : $R2"

# ------------------------------------------------------------------
# 2. PRÉPARATION DE LA BASE DE DONNÉES (GVDB)
# ------------------------------------------------------------------
GVDB_DIR="${BASE_DIR}/01_data/GVDB_genomes"
GVDB_NUCL="${GVDB_DIR}/GVDB_nucl"
REF_FASTA="${GVDB_DIR}/GVDB_mega_reference.fasta"

echo "🔄 Chargement de l'environnement conda env_mapping..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_mapping

if [ ! -f "${REF_FASTA}.bwt" ]; then
    echo "⚙️ 1/4 : Création du Méga-Génome (Fusion des 1382 virus)..."
    cat ${GVDB_NUCL}/*.fna ${GVDB_NUCL}/*.fasta 2>/dev/null > "$REF_FASTA"
    
    echo "🏗️ Indexation BWA en cours (Attention : Consomme beaucoup de RAM)..."
    bwa index "$REF_FASTA"
else
    echo "✅ 1/4 : Index BWA déjà prêt !"
fi

# ------------------------------------------------------------------
# 3. MAPPING BWA-MEM (Sans le filtre -f 2 pour garder les orphelins)
# ------------------------------------------------------------------
echo "🚀 2/4 : Mapping BWA-MEM et conversion BAM à la volée..."
BAM_Q10="${OUT_DIR}/${SAMPLE}_GVDB_Q10_sorted.bam"

# Utilisation d'un pipe optimisé pour ne pas saturer le disque avec un gros .sam
# On filtre avec -q 10 (MAPQ >= 10) pour s'assurer que le read est bien mappé.
# IMPORTANT : On ne met plus -f 2 pour garder les reads dont le "mate" (partenaire) a été perdu ou s'aligne trop loin (fréquent chez les virus géants).
bwa mem -t 14 "$REF_FASTA" "$R1" "$R2" | \
    samtools view -@ 14 -b -q 10 - | \
    samtools sort -@ 14 -o "$BAM_Q10"

echo "📦 3/4 : Indexation du fichier BAM trié..."
samtools index "$BAM_Q10"

# ------------------------------------------------------------------
# 4. STATISTIQUES ET ABONDANCES
# ------------------------------------------------------------------
echo "📊 4/4 : Comptage des abondances virales..."
TSV_OUT="${OUT_DIR}/${SAMPLE}_viral_abundance.tsv"

# idxstats donne : "Nom_Génome  Taille_Génome  Reads_Mappés  Reads_Non_Mappés"
# On filtre ceux avec > 0 reads et on trie du plus abondant au moins abondant
samtools idxstats "$BAM_Q10" | awk '$3 > 0 {print $0}' | sort -k3,3nr > "$TSV_OUT"

conda deactivate

echo "===================================================================="
echo "✅ MAPPING TERMINÉ POUR $SAMPLE !"
echo "🏆 TOP 10 DES VIRUS LES PLUS ABONDANTS :"
echo -e "GENOME_VIRAL\tTAILLE\tNB_READS\tNB_READS_ORPHELINS"
head -n 10 "$TSV_OUT" | column -t
echo "===================================================================="