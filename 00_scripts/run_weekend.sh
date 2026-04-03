#!/bin/bash
# ======================================================================
# MASTER SCRIPT - VERSION SILENCIEUSE INTELLIGENTE (IDEMPOTENTE)
# ======================================================================

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TRIMMED_DIR="${BASE_DIR}/02_results/01_trimmed"

echo "🌟 DÉMARRAGE DU RUN AUTOMATIQUE (MODE SILENCIEUX) 🌟"
echo "🕒 Début : $(date)"

# --- FONCTION MAGIQUE DE VÉRIFICATION ---
run_step() {
    local SCRIPT=$1
    local SAMPLE=$2
    local STEP_NAME=$3
    local EXPECTED_FILE=$4

    # On vérifie si la variable n'est pas vide
    if [ -n "$EXPECTED_FILE" ]; then
        # On vérifie si c'est un fichier plein (-s) OU un dossier existant (-d)
        if [ -s "$EXPECTED_FILE" ] || [ -d "$EXPECTED_FILE" ]; then
            echo "  ⏭️  [SKIP] $STEP_NAME (Déjà réalisé)"
            return 0 # Succès
        fi
    fi

    # Sinon, on lance le script silencieusement
    if ./00_scripts/$SCRIPT $SAMPLE > /dev/null 2>&1; then
        echo "  ✅  [OK] $STEP_NAME"
        return 0 # Succès
    else
        echo "  ❌  [ERREUR] $STEP_NAME a échoué."
        return 1 # Échec
    fi
}

# --- BOUCLE PRINCIPALE ---
for FILE in ${TRIMMED_DIR}/*_R1_001_val_1.fq.gz; do
    
    [ -e "$FILE" ] || continue
    FILENAME=$(basename "$FILE")
    SAMPLE=${FILENAME%%_S*}
    
    echo "----------------------------------------------------------"
    echo "🦠 ÉCHANTILLON : $SAMPLE [Début : $(date +%H:%M)]"
    echo "----------------------------------------------------------"
    
    # ==================================================================
    # 🎯 DÉFINITION DES FICHIERS ATTENDUS (Cibles)
    # Laisse "" si tu ne connais pas encore le fichier de sortie final
    # ==================================================================
    OUT_01="${BASE_DIR}/02_results/01_phix/${SAMPLE}/unmapped_R1.fastq" # Exemple de nom, à vérifier
    OUT_02="${BASE_DIR}/02_results/02_sortmerna/${SAMPLE}/non_rRNA_R1.fastq" # Exemple de nom, à vérifier
    OUT_03="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
    OUT_04="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_PR2_CLEAN.tsv"
    OUT_05="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
    OUT_06="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}/final-viral-combined.fa"
    OUT_07="" 
    OUT_08=""
    OUT_09=""
    OUT_10=""
    OUT_11=""
    OUT_12=""
    OUT_13=""
    OUT_14=""
    OUT_14_1="" 
    OUT_15=""
    OUT_15_1=""

    # ==================================================================
    # 🚀 EXÉCUTION EN CHAÎNE
    # ==================================================================
    run_step "01.1_remove_phix.sh" "$SAMPLE" "01 - PhiX" "$OUT_01" || continue
    run_step "02_sortmerna.sh" "$SAMPLE" "02 - SortMeRNA" "$OUT_02" || continue
    run_step "03_assembly_master.sh" "$SAMPLE" "03 - Assembly" "$OUT_03" || continue
    run_step "04_taxonomy_blast_ribo.sh" "$SAMPLE" "04 - Taxonomy" "$OUT_04" || continue
    run_step "05_clustering_mmseqs.sh" "$SAMPLE" "05 - Clustering" "$OUT_05" || continue
    run_step "06_virus_discovery_vs2.sh" "$SAMPLE" "06 - VirSorter2" "$OUT_06" || continue
    run_step "07_diamond_annotation_VS2.sh" "$SAMPLE" "07 - Annotation" "$OUT_07" || continue
    run_step "08_transdecoder_rescue_hmm.sh" "$SAMPLE" "08 - Rescue" "$OUT_08" || continue
    run_step "09_diamond_validation.sh" "$SAMPLE" "09 - Validation" "$OUT_09" || continue
    run_step "10_checkV_validation.sh" "$SAMPLE" "10 - CheckV" "$OUT_10" || continue
    run_step "11_final_viral_integration.sh" "$SAMPLE" "11 - Integration" "$OUT_11" || continue
    run_step "12_hmm_verification.sh" "$SAMPLE" "12 - HMM Check" "$OUT_12" || continue
    run_step "13_extract_phylogeny.sh" "$SAMPLE" "13 - Phylogeny" "$OUT_13" || continue
    run_step "14_mapping_gvdb.sh" "$SAMPLE" "14 - Mapping GVDB" "$OUT_14" || continue
    run_step "14.1_mapping_gvdb_withoutf2.sh" "$SAMPLE" "14.1 - Mapping Loose" "$OUT_14_1" || continue
    run_step "15_mapped_reads_assembly.sh" "$SAMPLE" "15 - Targeted Assembly" "$OUT_15" || continue
    run_step "15.1_mapped_reads_assembly_withoutf2.sh" "$SAMPLE" "15.1 - Final Assembly" "$OUT_15_1" || continue
    
    echo "✅ ÉCHANTILLON $SAMPLE TERMINÉ AVEC SUCCÈS"

done

echo "🎉 TOUT EST FINI ! Fin : $(date)"