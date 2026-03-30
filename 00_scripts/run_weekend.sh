#!/bin/bash
# ======================================================================
# MASTER SCRIPT - VERSION SILENCIEUSE CORRIGÉE
# ======================================================================

TRIMMED_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE/02_results/01_trimmed" 

echo "🌟 DÉMARRAGE DU RUN AUTOMATIQUE (MODE SILENCIEUX) 🌟"
echo "🕒 Début : $(date)"

# On cherche la bonne terminaison (_R1_001_val_1.fq.gz)
for FILE in ${TRIMMED_DIR}/*_R1_001_val_1.fq.gz; do
    
    [ -e "$FILE" ] || continue
    FILENAME=$(basename "$FILE")
    
    # On coupe tout ce qui se trouve après le "_S" pour n'avoir que le nom pur (ex: 10-21D-AC16)
    SAMPLE=${FILENAME%%_S*}
    
    if [ "$SAMPLE" == "MOCK_SAMPLE" ]; then continue; fi
    
    echo "----------------------------------------------------------"
    echo "🦠 ÉCHANTILLON : $SAMPLE [Début : $(date +%H:%M)]"
    echo "----------------------------------------------------------"
    
    ./00_scripts/01.1_remove_phix.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 01 - PhiX" && \
    ./00_scripts/02_sortmerna.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 02 - SortMeRNA" && \
    ./00_scripts/03_assembly_master.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 03 - Assembly" && \
    ./00_scripts/04_taxonomy_blast_ribo.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 04 - Taxonomy" && \
    ./00_scripts/05_clustering_mmseqs.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 05 - Clustering" && \
    ./00_scripts/06_virus_discovery_vs2.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 06 - VirSorter2" && \
    ./00_scripts/07_diamond_annotation_VS2.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 07 - Annotation" && \
    ./00_scripts/08_transdecoder_rescue_hmm.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 08 - Rescue" && \
    ./00_scripts/09_diamond_validation.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 09 - Validation" && \
    ./00_scripts/10_checkV_validation.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 10 - CheckV" && \
    ./00_scripts/11_final_viral_integration.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 11 - Integration" && \
    ./00_scripts/12_hmm_verification.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 12 - HMM Check" && \
    ./00_scripts/13_extract_phylogeny.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 13 - Phylogeny" && \
    ./00_scripts/14_mapping_gvdb.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 14 - Mapping GVDB" && \
    ./00_scripts/14.1_mapping_gvdb_withoutf2.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 14.1 - Mapping Loose" && \
    ./00_scripts/15_mapped_reads_assembly.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 15 - Targeted Assembly" && \
    ./00_scripts/15.1_mapped_reads_assembly_withoutf2.sh $SAMPLE > /dev/null 2>&1 && echo "  [OK] 15.1 - Final Assembly"
    
    if [ $? -eq 0 ]; then
        echo "✅ ÉCHANTILLON $SAMPLE TERMINÉ AVEC SUCCÈS"
    else
        echo "❌ ERREUR DÉTECTÉE SUR $SAMPLE (Arrêt de la chaîne)"
    fi
done

echo "🎉 TOUT EST FINI ! Fin : $(date)"