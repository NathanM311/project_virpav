#!/bin/bash
# ======================================================================
# MASTER SCRIPT - RUN WEEKEND (VERSION INTELLIGENTE V3 - ROBUSTE)
# ======================================================================

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TRIMMED_DIR="${BASE_DIR}/02_results/01_trimmed"
LOGS_DIR="${BASE_DIR}/03_logs"

# S'assure que le dossier de logs existe
mkdir -p "$LOGS_DIR"

# Liste des échantillons pour lesquels on force le saut de PhiX et SortMeRNA
SKIP_PHIX_SAMPLES="10-21D-AC16 1-0D-AC15 11-21D-AC35 12-21D-AC44 13-21D-AC96"

echo "🌟 DÉMARRAGE DU RUN AUTOMATIQUE (MODE SILENCIEUX & SÉCURISÉ) 🌟"
echo "🕒 Début : $(date)"

# --- FONCTION DE VÉRIFICATION AVEC GESTION DYNAMIQUE DES LOGS ---
run_step() {
    local SCRIPT=$1
    local SAMPLE=$2
    local STEP_NAME=$3
    local EXPECTED_TARGET=$4
    local STEP_LOG="${LOGS_DIR}/${SAMPLE}_${SCRIPT}.error.log"

    # Si la cible existe (fichier non vide -s ou dossier -d), on saute
    if [ -n "$EXPECTED_TARGET" ] && { [ -s "$EXPECTED_TARGET" ] || [ -d "$EXPECTED_TARGET" ]; }; then
        echo "  Cellule : $SAMPLE | ⏭️  [SKIP] $STEP_NAME"
        return 0
    else
        # Exécution silencieuse, mais on capture tout dans un fichier log temporaire
        if ./00_scripts/$SCRIPT "$SAMPLE" > "$STEP_LOG" 2>&1; then
            echo "  Cellule : $SAMPLE | ✅  [OK] $STEP_NAME"
            rm -f "$STEP_LOG" # Succès : on nettoie le log pour rester discret
            return 0
        else
            echo "  Cellule : $SAMPLE | ❌  [ERREUR CRITIQUE] $STEP_NAME a échoué."
            echo "      ⚠️ EXTRAIT DE L'ERREUR (Détails conservés dans : $STEP_LOG) :"
            tail -n 10 "$STEP_LOG" | sed 's/^/      > /'
            return 1 # Fait échouer la suite logique pour cet échantillon
        fi
    fi
}

# --- BOUCLE PRINCIPALE ---
# On boucle sur les vrais fichiers FASTQ bruts
for FILE in "${TRIMMED_DIR}"/*_R1_001_val_1.fq.gz; do
    
    [ -e "$FILE" ] || continue
    FILENAME=$(basename "$FILE")
    SAMPLE=${FILENAME%%_S*}
    
    echo "----------------------------------------------------------"
    echo "🦠 ÉCHANTILLON : $SAMPLE [$(date +%H:%M)]"
    echo "----------------------------------------------------------"
    
    # --- LOGIQUE DE SAUT POUR ÉTAPE 01 & 02 ---
    if [[ $SKIP_PHIX_SAMPLES =~ $SAMPLE ]]; then
        OUT_01="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}"
        OUT_02="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}"
    else
        OUT_01="${BASE_DIR}/02_results/02_phix_removed/${SAMPLE}/${SAMPLE}_no_phix_R1.fq.gz"
        OUT_02="${BASE_DIR}/02_results/03_sortmerna/${SAMPLE}/${SAMPLE}_ribosome_fwd.fq.gz"
    fi

    # --- CIBLES POUR LES ÉTAPES SUIVANTES ---
    OUT_03="${BASE_DIR}/02_results/04_assembly/${SAMPLE}/ribosome_trinity.Trinity.fasta"
    OUT_04="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}/${SAMPLE}_vs_PR2_CLEAN.tsv"
    OUT_05="${BASE_DIR}/02_results/06_clustering/${SAMPLE}/mmseqs_out_rep_seq.fasta"
    OUT_06="${BASE_DIR}/02_results/07_virsorter2/${SAMPLE}/final-viral-combined.fa"
    OUT_07="${BASE_DIR}/02_results/08_annotation_virsorter2/${SAMPLE}/${SAMPLE}_vs_nr.tsv"
    OUT_08="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}/candidates_to_blast.faa"
    OUT_09="${BASE_DIR}/02_results/09_annotation_hmm/${SAMPLE}/diamond_nr_validation.tsv"
    OUT_10="${BASE_DIR}/02_results/10_checkv/${SAMPLE}/checkv_results/quality_summary.tsv"
    OUT_11="${BASE_DIR}/02_results/11_final_integration/${SAMPLE}/final_annotated_viruses.tsv"
    OUT_12="${BASE_DIR}/02_results/12_verification_hmm/${SAMPLE}/2_best_hits_translated.tsv"
    OUT_13="" # L'étape 13 ne doit pas tourner en auto (dépend d'un mot-clé manuel)
    OUT_14="${BASE_DIR}/02_results/14_mapping_gvdb/${SAMPLE}/${SAMPLE}_GVDB_Q10_sorted.bam"
    OUT_14_1="${BASE_DIR}/02_results/14.1_mapping_gvdb_withoutf2/${SAMPLE}/${SAMPLE}_GVDB_Q10_sorted.bam"
    OUT_15="${BASE_DIR}/02_results/15_targeted_assembly/${SAMPLE}/spades_assembly/scaffolds.fasta"
    OUT_15_1="${BASE_DIR}/02_results/15.1_targeted_assembly_withoutf2/${SAMPLE}/spades_assembly/scaffolds.fasta"
    # === NOUVELLE CIBLE 16 ===
    OUT_16="${BASE_DIR}/02_results/16_quantification_kallisto_all/${SAMPLE}/${SAMPLE}_abundance_clustered_TPM.tsv"

    # --- EXÉCUTION DES SCRIPTS EN CASCADE ---
    # Le '|| continue' permet de passer à l'échantillon suivant si une étape critique échoue
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
    
    # Scripts de mapping isolés (ne font pas crasher la boucle principale s'ils échouent)
    run_step "14_mapping_gvdb.sh" "$SAMPLE" "14 - Mapping GVDB" "$OUT_14"
    run_step "14.1_mapping_gvdb_withoutf2.sh" "$SAMPLE" "14.1 - Mapping Loose" "$OUT_14_1"
    run_step "15_mapped_reads_assembly.sh" "$SAMPLE" "15 - Targeted Assembly" "$OUT_15"
    run_step "15.1_mapped_reads_assembly_withoutf2.sh" "$SAMPLE" "15.1 - Final Assembly" "$OUT_15_1"
    
    # === NOUVELLE ÉTAPE 16 ===
    run_step "16_quantification_kallisto_all.sh" "$SAMPLE" "16 - Quantification Kallisto" "$OUT_16"
    
    echo "🏁 ÉCHANTILLON $SAMPLE BOUCLÉ."

done

echo "🎉 TOUTES LES ANALYSES SONT TERMINÉES ! Fin : $(date)"