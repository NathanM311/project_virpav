#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 08 : ANNOTATION PROTÉIQUE (TRANSDECODER + RESCUE) & SCAN HMM
# ------------------------------------------------------------------

START_TIME=$(date +%s)
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
SAMPLE=${1:-"MOCK_SAMPLE"}

IN_FASTA="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
OUT_DIR="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}"
DB_DIR="${BASE_DIR}/01_data/hmm" # Vérifie bien que tes .hmm sont ici !

mkdir -p $OUT_DIR
cd $OUT_DIR

echo "🔄 Chargement de l'environnement env_annot..."
source $HOME/miniconda3/etc/profile.d/conda.sh

# On s'assure que seqkit ET emboss (pour getorf) sont installés
if ! conda list -n env_annot | grep -q "emboss"; then
    conda install -n env_annot -c bioconda seqkit emboss -y
fi
conda activate env_annot

ln -sf $IN_FASTA transcripts.fasta

echo "===================================================================="
echo "🧬 1/5 : VOIE PRINCIPALE (TransDecoder + Pfam)"
echo "===================================================================="

# 💡 CORRECTION 1 : Nettoyage des anciens runs pour forcer TransDecoder à tout refaire
rm -rf transcripts.fasta.transdecoder_dir* transcripts.fasta.transdecoder.* pfam.domtblout PROTEINS_TD.pep

TransDecoder.LongOrfs -t transcripts.fasta

hmmsearch --cpu 14 -E 1e-5 --domtblout pfam.domtblout \
          ${DB_DIR}/Pfam-A.hmm transcripts.fasta.transdecoder_dir/longest_orfs.pep

# 💡 CORRECTION 2 : Vérifier les vrais hits (ignorer les lignes de commentaires commençant par #)
if [ $(grep -v "^#" pfam.domtblout | wc -l) -gt 0 ]; then
    echo "✅ Pfam détecté, utilisation pour la prédiction finale..."
    TransDecoder.Predict -t transcripts.fasta --retain_pfam_hits pfam.domtblout
else
    echo "⚠️ Attention: Aucun hit Pfam significatif. Prédiction sans Pfam."
    TransDecoder.Predict -t transcripts.fasta
fi

mv transcripts.fasta.transdecoder.pep PROTEINS_TD.pep

echo "===================================================================="
echo "🧩 2/5 : VOIE SECONDAIRE (Rescue avec getorf)"
echo "===================================================================="
awk '/^>/{print $1}' PROTEINS_TD.pep | sed 's/>//' | sed 's/\.p[0-9]*$//' | sort | uniq > ids_translated_by_TD.txt
seqkit grep -v -f ids_translated_by_TD.txt transcripts.fasta > contigs_rejected.fasta

# Utilisation de getorf (qui traduit directement en protéines)
getorf -sequence contigs_rejected.fasta -outseq PROTEINS_RESCUE.pep -minsize 90

echo "📊 Statistiques :"
echo " - Contigs traduits (TransDecoder) : $(wc -l < ids_translated_by_TD.txt)"
echo " - Contigs traduits (Rescue getorf): $(grep -c "^>" contigs_rejected.fasta)"
echo " - ORFs récupérés (Rescue)         : $(grep -c "^>" PROTEINS_RESCUE.pep)"

echo "===================================================================="
echo "🦠 3/5 & 4/5 : SCAN HMM (GVDB et VOGDB)"
echo "===================================================================="
# Scan sur TD
hmmsearch --cpu 14 -E 1e-5 --tblout GVDB_hits_TD.tsv ${DB_DIR}/GVDB.hmm PROTEINS_TD.pep > /dev/null
hmmsearch --cpu 14 -E 1e-5 --tblout VOGDB_hits_TD.tsv ${DB_DIR}/VOG.hmm PROTEINS_TD.pep > /dev/null
# Scan sur Rescue
hmmsearch --cpu 14 -E 1e-5 --tblout GVDB_hits_RESCUE.tsv ${DB_DIR}/GVDB.hmm PROTEINS_RESCUE.pep > /dev/null
hmmsearch --cpu 14 -E 1e-5 --tblout VOGDB_hits_RESCUE.tsv ${DB_DIR}/VOG.hmm PROTEINS_RESCUE.pep > /dev/null

echo "===================================================================="
echo "🔗 5/5 : EXTRACTION DES CANDIDATS (Le chaînon manquant !)"
echo "===================================================================="
cat PROTEINS_TD.pep PROTEINS_RESCUE.pep > ALL_PROTEINS_TD_RESCUE.pep
cat GVDB_hits_TD.tsv VOGDB_hits_TD.tsv GVDB_hits_RESCUE.tsv VOGDB_hits_RESCUE.tsv 2>/dev/null | grep -v "^#" | awk '{print $1}' | sort | uniq > viral_candidate_ids.txt
seqkit grep -f viral_candidate_ids.txt ALL_PROTEINS_TD_RESCUE.pep > candidates_to_blast.faa

conda deactivate
echo "✅ PIPELINE 08 TERMINÉ !"