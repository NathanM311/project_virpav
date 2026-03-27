#!/bin/bash
# Script pour lancer le mapping et l'assemblage sur tous les échantillons

BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
READS_DIR="${BASE_DIR}/02_results/02_phix_removed"

echo "🌟 DÉMARRAGE DU RUN DU WEEK-END 🌟"

# On boucle sur tous les dossiers présents dans 02_phix_removed
for DIR in ${READS_DIR}/*; do
    if [ -d "$DIR" ]; then
        SAMPLE=$(basename "$DIR")
        
        # On ignore le MOCK_SAMPLE car il est déjà fait
        if [ "$SAMPLE" == "MOCK_SAMPLE" ]; then
            continue
        fi
        
        echo "=========================================================="
        echo "🦠 TRAITEMENT DE L'ÉCHANTILLON : $SAMPLE"
        echo "=========================================================="
        
        # On lance les scripts à la chaîne avec "&&" pour s'arrêter si l'un plante
        ./00_scripts/14_mapping_gvdb.sh $SAMPLE && \
        ./00_scripts/14.1_mapping_gvdb_withoutf2.sh $SAMPLE && \
        ./00_scripts/15_mapped_reads_assembly.sh $SAMPLE && \
        ./00_scripts/15.1_mapped_reads_assembly_withoutf2.sh $SAMPLE
        
        echo "✅ FIN POUR L'ÉCHANTILLON $SAMPLE"
    fi
done

echo "🎉 TOUS LES ÉCHANTILLONS ONT ÉTÉ TRAITÉS !"