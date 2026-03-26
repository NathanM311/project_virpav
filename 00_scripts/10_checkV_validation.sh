#!/bin/bash
# ------------------------------------------------------------------
# SCRIPT 10 : VALIDATION DES VIRUS AVEC CHECKV (Gold Standard)
# Utilisation : ./00_scripts/10_checkv_validation.sh <NOM_ECHANTILLON>
# Exemple     : ./00_scripts/10_checkv_validation.sh 10-21D-AC16
# ------------------------------------------------------------------

# 1. Gestion de l'échantillon (prend l'argument 1, ou 10-21D-AC16 par défaut)
SAMPLE=${1:-"10-21D-AC16"}

echo "===================================================================="
echo "🚀 DÉMARRAGE DE CHECKV POUR L'ÉCHANTILLON : $SAMPLE"
echo "===================================================================="

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
HMM_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
OUT_DIR="${BASE_DIR}/02_results/10_checkv/${SAMPLE}"

# Le chemin exact (corrigé) vers la base de données CheckV
DB_DIR="${BASE_DIR}/01_data/databases/checkv_db/checkv-db-v1.5"
THREADS=14

mkdir -p $OUT_DIR

# 2. Chargement de l'environnement Conda
echo "🔄 Chargement de l'environnement conda env_checkv..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate env_checkv

# 3. Préparation des séquences (Le correctif des IDs)
echo "===================================================================="
echo "🧹 NETTOYAGE ET EXTRACTION DES CONTIGS CANDIDATS"
echo "===================================================================="

# On supprime les suffixes .p1, .p2 (TransDecoder) et _1, _2 (getorf) pour retrouver le vrai nom du contig
sed -E 's/\.p[0-9]+$//; s/_[0-9]+$//' ${HMM_DIR}/viral_candidate_ids.txt | sort | uniq > ${OUT_DIR}/clean_contig_ids.txt

# Extraction des séquences nucléotidiques entières depuis le FASTA d'assemblage
seqkit grep -f ${OUT_DIR}/clean_contig_ids.txt ${HMM_DIR}/transcripts.fasta -o ${OUT_DIR}/viral_candidates_CONTIGS.fasta

CONTIG_COUNT=$(grep -c "^>" ${OUT_DIR}/viral_candidates_CONTIGS.fasta || echo 0)
echo "📊 Nombre de contigs envoyés à CheckV : $CONTIG_COUNT"

if [ "$CONTIG_COUNT" -eq 0 ]; then
    echo "❌ ERREUR : Aucun contig extrait. L'outil ne trouve pas les séquences."
    exit 1
fi

# 4. Lancement de l'analyse CheckV
echo "===================================================================="
echo "🛡️ LANCEMENT DE L'ANALYSE CHECKV (End-to-End)"
echo "===================================================================="
# On supprime le dossier de résultats s'il existe déjà pour éviter que CheckV plante
rm -rf ${OUT_DIR}/checkv_results

checkv end_to_end \
    ${OUT_DIR}/viral_candidates_CONTIGS.fasta \
    ${OUT_DIR}/checkv_results \
    -t $THREADS \
    -d $DB_DIR

conda deactivate

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
M=$((ELAPSED / 60))

echo "===================================================================="
echo "✅ CHECKV TERMINÉ EN ${M} MINUTES POUR $SAMPLE !"
echo "📁 Tes résultats finaux sont dans : ${OUT_DIR}/checkv_results/quality_summary.tsv"
echo "===================================================================="