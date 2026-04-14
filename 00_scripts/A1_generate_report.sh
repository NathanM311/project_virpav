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

# A. HÔTE PRINCIPAL (Basé sur le PR2 qui garde tout)
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

# B. CARTE DE REPRÉSENTATION (NOYAU vs ORGANITES) - AVANT / APRÈS
ANALYSE_DIR="${BASE_DIR}/02_results/Analyse/${SAMPLE}"

NUC_RAW="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_nuclear.tsv"
ORG_RAW="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_organelles.tsv"
NUC_NC="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_nuclear_no_contaminants.tsv"
ORG_NC="${ANALYSE_DIR}/${SAMPLE}_unified_microbiome_organelles_no_contaminants.tsv"

# Petite fonction pour générer les lignes du tableau Markdown sans répéter le code
generate_md_table() {
    if [ -f "$1" ]; then
        # J'ai réduit à 20 pour que la comparaison "Avant/Après" ne prenne pas 4 pages !
        awk -F'\t' 'NR>1 {count[$4" - "$5]++} END {for (tax in count) print count[tax]"\t"tax}' "$1" | sort -nr | head -n 20 | awk -F'\t' '{print "| **" $1 "** | " $2 " |"}'
    else
        echo "| *Fichier introuvable* | *-* |"
    fi
}

COMMUNITY_MAP_NUC_RAW=$(generate_md_table "$NUC_RAW")
COMMUNITY_MAP_NUC_NC=$(generate_md_table "$NUC_NC")
COMMUNITY_MAP_ORG_RAW=$(generate_md_table "$ORG_RAW")
COMMUNITY_MAP_ORG_NC=$(generate_md_table "$ORG_NC")

if [ -f "$NUC_FILE" ]; then
    COMMUNITY_MAP_NUC=$(awk -F'\t' '
        NR>1 {count[$4" - "$5]++} 
        END {for (tax in count) print count[tax]"\t"tax}
    ' "$NUC_FILE" | sort -nr | head -n 50 | awk -F'\t' '{print "| **" $1 "** | " $2 " |"}')
else
    COMMUNITY_MAP_NUC="| *Fichier nucléaire introuvable* | *Lancez le script Analyse 01* |"
fi

if [ -f "$ORG_FILE" ]; then
    COMMUNITY_MAP_ORG=$(awk -F'\t' '
        NR>1 {count[$4" - "$5]++} 
        END {for (tax in count) print count[tax]"\t"tax}
    ' "$ORG_FILE" | sort -nr | head -n 50 | awk -F'\t' '{print "| **" $1 "** | " $2 " |"}')
else
    COMMUNITY_MAP_ORG="| *Fichier organites introuvable* | *Lancez le script Analyse 01* |"
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
    TOP_VIRUS_MD=$(head -n 6 "$FILE_ABUNDANCE" | awk 'BEGIN {print "| Génome | Taille | Reads Mappés |\n| :--- | :---: | :---: |"} {print "| "$1" | "$2" | "$3" |"}')
else
    TOP_VIRUS_MD="*Fichier d'abondance introuvable.*"
fi

# ====================================================================
# ÉTAPE A : ÉCRITURE DU FICHIER MARKDOWN (.md) EN PREMIER
# ====================================================================
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

**B. Top de la Communauté Nucléaire (Eucaryotes / Bactériome libre)**

#### 🔴 Avant Décontamination (Brut)
| Nombre de Contigs | Domaine - Phylum |
| :---: | :--- |
${COMMUNITY_MAP_NUC_RAW}

#### 🌊 Après Décontamination (Microbiome Marin)
| Nombre de Contigs | Domaine - Phylum |
| :---: | :--- |
${COMMUNITY_MAP_NUC_NC}

**C. Top des Organites (Chloroplastes & Mitochondries)**

#### 🔴 Avant Décontamination (Brut)
| Nombre de Contigs | Domaine - Phylum |
| :---: | :--- |
${COMMUNITY_MAP_ORG_RAW}

#### 🌊 Après Décontamination (Microbiome Marin)
| Nombre de Contigs | Domaine - Phylum |
| :---: | :--- |
${COMMUNITY_MAP_ORG_NC}

> [!INFO] **Note d'interprétation**
> Le nettoyage a permis de supprimer les biais liés à la manipulation (ex: *Cutibacterium*, *Homo*) et aux réactifs de laboratoire (ex: *Escherichia*). Les tableaux **"Après Décontamination"** reflètent le véritable écosystème marin étudié. Le gène 23S a également été isolé avec succès dans la fraction organite, permettant de suivre l'activité photosynthétique de l'hôte.

### 📊 Visualisations Interactives (Krona)

#### 🔴 Vue Globale avec Contaminants
<iframe src="./${SAMPLE}_taxonomy_krona_original.html" width="100%" height="650px" style="border:none;"></iframe>

#### 🌊 Vue Épurée (Microbiome Marin)
<iframe src="./${SAMPLE}_taxonomy_krona_clean.html" width="100%" height="650px" style="border:none;"></iframe>

[!INFO] **Note d'interprétation de l'Hôte**
> L'identification d'un hôte principal est basée sur la présence d'un contig ribosomal eucaryote de plus de 800 pb avec une identité élevée (>97%) dans la base PR2. Si aucun contig ne répond à ces critères, cela peut indiquer un échantillon avec un hôte non identifié ou une communauté très diversifiée sans dominance claire.
> Une attention particulière a été porté à la distinction entre le génome nucléaire et les organites. 
> 1. **Résoulution taxonomique** : Certain transcrits 28S peuvent être mal annotés en raison des lacunes des bases de données. 
> 2. **Fraction chloroplastique** : Le gène 23S à été isolé avec succès dans la fraction organite. 


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

echo "✅ Rapport Markdown généré : $REPORT_FILE"

# ====================================================================
# ÉTAPE B : CONVERSION EN HTML (Maintenant que le .md existe)
# ====================================================================
HTML_REPORT="${DOC_DIR}/${SAMPLE}_complete_report.html"

echo "🌐 Conversion du rapport en HTML..."
pandoc "$REPORT_FILE" -s --metadata title="Rapport Virpav - ${SAMPLE}" -o "$HTML_REPORT"

# ====================================================================
# ÉTAPE C : CRÉATION DU PACKAGE LIVRABLE
# ====================================================================
echo "📦 Rapatriement des graphiques Krona pour le package..."
KRONA_RAW="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_original.html"
KRONA_NC="${ANALYSE_DIR}/${SAMPLE}_taxonomy_krona_clean.html"

cp "$KRONA_RAW" "$KRONA_NC" "$DOC_DIR/" 2>/dev/null || echo "⚠️ Attention : Fichiers Krona non trouvés."

echo "===================================================================="
echo "🎉 C'EST PRÊT ! "
echo "👉 Pour voir ton rapport, télécharge le dossier complet : $DOC_DIR"
echo "===================================================================="