#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 16 (V3 - LONG) : RAPPORT D'ANALYSE COMPLET (OBSIDIAN READY)
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
DOC_DIR="${BASE_DIR}/05_docs/reports"
mkdir -p "$DOC_DIR"

echo "===================================================================="
echo "📊 GÉNÉRATION DU RAPPORT DÉTAILLÉ : $SAMPLE"
echo "===================================================================="

# --- 1. MÉTRIQUES DES READS (Qualité & Nettoyage) ---
PHIX_LOG="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}/${SAMPLE}_phix_stats.txt"

if [ -f "$PHIX_LOG" ]; then
    NB_INITIAL_PAIRS=$(grep "reads; of these:" "$PHIX_LOG" | awk '{sum+=$1} END {print sum+0}')
    NB_CLEAN_PAIRS=$(grep "%) aligned concordantly 0 times" "$PHIX_LOG" | awk '{sum+=$1} END {print sum+0}')
    TOTAL_READS=$((NB_INITIAL_PAIRS * 2))
    PHIX_REMOVED=$(((NB_INITIAL_PAIRS - NB_CLEAN_PAIRS) * 2))
    PHIX_RATE=$(grep "overall alignment rate" "$PHIX_LOG" | tail -n 1 | awk '{print $1}')
else
    TOTAL_READS="N/A"
    PHIX_REMOVED="N/A"
    PHIX_RATE="N/A"
fi

# SortMeRNA
RIBO_FQ="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_fwd.fq.gz"
NORIBO_FQ="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_noribosome_fwd.fq.gz"

if [ -f "$RIBO_FQ" ] && [ -f "$NORIBO_FQ" ]; then
    READS_RIBO=$(zgrep -c "^@" "$RIBO_FQ" || echo 0)
    READS_NONRIBO=$(zgrep -c "^@" "$NORIBO_FQ" || echo 0)
    TOTAL_SMR=$((READS_RIBO + READS_NONRIBO))
    PCT_RIBO=$(awk "BEGIN {pc=($READS_RIBO/$TOTAL_SMR)*100; printf \"%.2f\", pc}")
else
    PCT_RIBO="N/A"
fi

# --- 2. DÉNOMBREMENT TRINITY RIBOSOMIQUE ---
FILE_RIBO_TRINITY="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
if [ -f "$FILE_RIBO_TRINITY" ]; then
    NB_RIBO_TRINITY=$(grep -c "^>" "$FILE_RIBO_TRINITY")
else
    NB_RIBO_TRINITY="0"
fi

# --- 3. PORTRAIT DE L'HÔTE & CARTE DE LA COMMUNAUTÉ ---
PR2_FILE="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_PR2_CLEAN.tsv"
SILVA_FILE="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_SILVA_SSU_CLEAN.tsv"

# A. HÔTE PRINCIPAL
MAIN_HOST="*Aucun contig ribosomal Eucaryote > 800pb trouvé.*"
if [ -f "$PR2_FILE" ]; then
    TOP_HIT=$(awk -F'\t' 'NR>1 {
        id=$15; gsub(/,/, ".", id);
        if ($16 >= 800 && id >= 97) {
            split($2, acc, "."); ncbi = acc[1] "." acc[2];
            print $14 "\t" id "\t" $16 "\t" $18 "\t" ncbi
        }
    }' "$PR2_FILE" | sort -k4,4nr | head -n 1)

    if [ -n "$TOP_HIT" ]; then
        SPECIES=$(echo "$TOP_HIT" | awk -F'\t' '{print $1}')
        ID=$(echo "$TOP_HIT" | awk -F'\t' '{print $2}')
        LEN=$(echo "$TOP_HIT" | awk -F'\t' '{print $3}')
        NCBI=$(echo "$TOP_HIT" | awk -F'\t' '{print $5}')
        MAIN_HOST="🧬 **${SPECIES}** (Accession : \`${NCBI}\` | Identité : ${ID}% | Longueur : ${LEN} pb)"
    fi
fi

# B. CARTE DE REPRÉSENTATION (Mise à jour avec le fichier unifié !)
COMMUNITY_MAP=""
UNIFIED_FILE="${BASE_DIR}/02_results/Analyse/${SAMPLE}/${SAMPLE}_unified_microbiome_detailed.tsv"

if [ -f "$UNIFIED_FILE" ]; then
    # J'ai laissé ton head -n 100 si tu veux une longue liste !
    COMMUNITY_MAP=$(awk -F'\t' '
        NR>1 {count[$4" - "$5]++} 
        END {for (tax in count) print count[tax]"\t"tax}
    ' "$UNIFIED_FILE" | sort -nr | head -n 100 | awk -F'\t' '{print "| **" $1 "** | " $2 " |"}')
else
    COMMUNITY_MAP="| *Fichier unifié introuvable* | *Lancez le script Analyse 01* |"
fi

# --- 4. ANALYSE DES CONTIGS GLOBAUX & VIRUS ---
FILE_CLUST="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
if [ -f "$FILE_CLUST" ]; then
    NB_CONTIGS=$(grep -c "^>" "$FILE_CLUST")
else
    NB_CONTIGS="N/A"
fi

FILE_VS2="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}/final-viral-combined.fa"
if [ -f "$FILE_VS2" ]; then
    NB_VIRAUX=$(grep -c "^>" "$FILE_VS2")
else
    NB_VIRAUX="N/A"
fi

FILE_PURE="${BASE_DIR}/02_results/11_final_integration/${SAMPLE}/pure_contig_ids.txt"
if [ -f "$FILE_PURE" ]; then
    NB_PURS=$(wc -l < "$FILE_PURE")
else
    NB_PURS="0"
fi

# Fonctions HMM
HMM_FILE="${BASE_DIR}/02_results/12_verification_hmm/${SAMPLE}/2_best_hits_translated.tsv"
if [ -f "$HMM_FILE" ]; then
    TOP_FUNCTIONS=$(tail -n +2 "$HMM_FILE" | awk -F'\t' '{print $5}' | sort | uniq -c | sort -nr | head -n 5 | awk '{print "| " $0 " |"}' | sed 's/| \([0-9]*\) /| \1 | /')
else
    TOP_FUNCTIONS="| Aucune fonction annotée |"
fi

# Assemblage Ciblé (SPAdes)
SPADES_FILE="${BASE_DIR}/02_results/15_targeted_assembly/${SAMPLE}/spades_assembly/scaffolds.fasta"
if [ -f "$SPADES_FILE" ]; then
    NB_TARGET=$(grep -c "^>" "$SPADES_FILE")
else
    NB_TARGET="0"
fi

# --- 5. ABONDANCE GVDB ---
FILE_ABUNDANCE="${BASE_DIR}/02_results/14_mapping_gvdb/${SAMPLE}/${SAMPLE}_viral_abundance.tsv"
if [ -f "$FILE_ABUNDANCE" ]; then
    # On ajoute des sauts de ligne autour du header pour Markdown
    TOP_VIRUS_MD=$(head -n 6 "$FILE_ABUNDANCE" | awk 'BEGIN {print "| Génome | Taille | Reads Mappés |\n| :--- | :---: | :---: |"} {print "| "$1" | "$2" | "$3" |"}')
else
    TOP_VIRUS_MD="*Fichier d'abondance introuvable.*"
fi

# --- CONSTRUCTION DU MARKDOWN ---
REPORT_FILE="${DOC_DIR}/${SAMPLE}_complete_report.md"

cat << EOF > "$REPORT_FILE"
# 🦠 Rapport d'Analyse Virpav - Échantillon : ${SAMPLE}
*Date de génération : $(date "+%Y-%m-%d %H:%M")*

---

## 1. Statistiques des Séquences (Nettoyage)
* **Nombre total de reads bruts (R1+R2)** : **${TOTAL_READS}**
* **Reads retirés (Contamination PhiX)** : **${PHIX_REMOVED}** (${PHIX_RATE})
* **Fraction ARNr détectée (SortMeRNA)** : **${PCT_RIBO}%**

## 2. Portrait de l'Hôte et Carte du Microbiome
* **Assemblage Ribosomique (Trinity)** : **${NB_RIBO_TRINITY}** contigs reconstruits.

**A. Espèce Hôte Dominante (Top Hit 18S)**
* ${MAIN_HOST}

**B. Top de la Communauté Globale (PR2 + SILVA SSU/LSU)**

| Nombre de Contigs | Domaine - Phylum |
| :---: | :--- |
${COMMUNITY_MAP}

## 3. Analyse des Contigs et Virus
* **Assemblage global (MMseqs2)** : ${NB_CONTIGS} contigs uniques.
* **Candidats VirSorter2** : ${NB_VIRAUX} contigs identifiés.
* **Génomes Ultra-Purs (CheckV/Diamond)** : **${NB_PURS}**.
* **Assemblage Ciblé (SPAdes)** : ${NB_TARGET} scaffolds viraux reconstruits.

## 4. Fonctions Biologiques Dominantes (HMM)

| Occurrences | Fonction Biologique |
| :---: | :--- |
${TOP_FUNCTIONS}

## 5. Abondance GVDB (Recrutement de reads)

${TOP_VIRUS_MD}

---
EOF

echo "✅ Rapport complet généré : $REPORT_FILE"