#!/bin/bash
# ======================================================================
# MASTER SCRIPT - RUN WEEKEND (VERSION INTELLIGENTE V3)
# ======================================================================

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TRIMMED_DIR="${BASE_DIR}/02_results/01_trimmed"

# Liste des échantillons pour lesquels on force le saut de PhiX et SortMeRNA
SKIP_PHIX_SAMPLES="10-21D-AC16 1-0D-AC15 11-21D-AC35 12-21D-AC44 13-21D-AC96"

echo "🌟 DÉMARRAGE DU RUN AUTOMATIQUE (MODE SILENCIEUX) 🌟"
echo "🕒 Début : $(date)"

# --- FONCTION DE VÉRIFICATION ---
run_step() {
    local SCRIPT=$1
    local SAMPLE=$2
    local STEP_NAME=$3
    local EXPECTED_TARGET=$4

    # Si la cible existe (fichier non vide -s ou dossier -d), on saute
    if [ -n "$EXPECTED_TARGET" ] && { [ -s "$EXPECTED_TARGET" ] || [ -d "$EXPECTED_TARGET" ]; }; then
        echo "  Check : $EXPECTED_TARGET trouvé." >> "${BASE_DIR}/03_logs/debug_steps.log"
        echo "  Cellule : $SAMPLE | ⏭️  [SKIP] $STEP_NAME"
        return 0
    else
        if ./00_scripts/$SCRIPT "$SAMPLE" > /dev/null 2>&1; then
            echo "  Cellule : $SAMPLE | ✅  [OK] $STEP_NAME"
            return 0
        else
            echo "  Cellule : $SAMPLE | ❌  [ERREUR] $STEP_NAME"
            return 1
        fi
    fi
}

# --- BOUCLE PRINCIPALE ---
for FILE in "${TRIMMED_DIR}"/*_R1_001_val_1.fq.gz; do
    
    [ -e "$FILE" ] || continue
    FILENAME=$(basename "$FILE")
    SAMPLE=${FILENAME%%_S*}
    
    echo "----------------------------------------------------------"
    echo "🦠 ÉCHANTILLON : $SAMPLE [$(date +%H:%M)]"
    echo "----------------------------------------------------------"
    
    # --- LOGIQUE DE SAUT POUR ÉTAPE 01 & 02 ---
    # Si l'échantillon est dans la liste fournie, on pointe vers le dossier existant pour forcer le SKIP
    if [[ $SKIP_PHIX_SAMPLES =~ $SAMPLE ]]; then
        OUT_01="${BASE_DIR}/02_results/01_phix/${SAMPLE}"
        OUT_02="${BASE_DIR}/02_results/02_sortmerna/${SAMPLE}"
    else
        # Pour les autres, on ne saute que si un fichier de succès spécifique existe (plus prudent)
        OUT_01="${BASE_DIR}/02_results/01_phix/${SAMPLE}/.step_done"
        OUT_02="${BASE_DIR}/02_results/02_sortmerna/${SAMPLE}/.step_done"
    fi

    # --- LOGIQUE DE SAUT POUR LES AUTRES ÉTAPES ---
    OUT_03="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
    OUT_04="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_PR2_CLEAN.tsv"
    OUT_05="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
    OUT_06="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}/final-viral-combined.fa"

    # Étapes suivantes : Laissées vides "" pour qu'elles tournent sur tout le monde (jusqu'à validation)
    OUT_07=""; OUT_08=""; OUT_09=""; OUT_10=""; OUT_11=""; OUT_12=""; OUT_13=""; OUT_14=""; OUT_14_1=""; OUT_15=""; OUT_15_1=""

    # --- EXÉCUTION DES SCRIPTS ---
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
    
    echo "✅ ÉCHANTILLON $SAMPLE TERMINÉ"

done

echo "🎉 PIPELINE TERMINÉ ! $(date)"