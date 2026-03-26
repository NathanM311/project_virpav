#!/bin/bash
# ------------------------------------------------------------------
# MASTER SCRIPT DE NUIT : Lancement séquentiel de 08 à 15
# ------------------------------------------------------------------

SAMPLE=${1:-"MOCK_SAMPLE"}
LOG_DIR="03_logs/run_nuit_${SAMPLE}"

# On crée un dossier spécial pour tes logs de la nuit
mkdir -p $LOG_DIR

echo "======================================================="
echo "🌙 DÉMARRAGE DU RUN DE NUIT POUR : $SAMPLE"
echo "📂 Les logs seront sauvegardés dans : $LOG_DIR"
echo "======================================================="

# Lancement du 08
echo "⏳ [1/8] Exécution du Script 08 (Annotation)..."
./00_scripts/08_transdecoder_rescue_hmm.sh $SAMPLE > $LOG_DIR/08_transdecoder_rescue_hmm.log 2>&1
echo "✅ 08 Terminé !"

# Lancement du 09
echo "⏳ [2/8] Exécution du Script 09 (Diamond)..."
./00_scripts/09_diamond_validation.sh $SAMPLE > $LOG_DIR/09_diamond_validation.log 2>&1
echo "✅ 09 Terminé !"

# Lancement du 10
echo "⏳ [3/8] Exécution du Script 10 (CheckV)..."
./00_scripts/10_checkV_validation.sh $SAMPLE > $LOG_DIR/10_checkV_validation.log 2>&1
echo "✅ 10 Terminé !"

# Lancement du 11
echo "⏳ [4/8] Exécution du Script 11 (CheckV)..."
./00_scripts/11_final_viral_integration.sh $SAMPLE > $LOG_DIR/11_final_viral_integration.log 2>&1
echo "✅ 11 Terminé !"

# Lancement du 12
echo "⏳ [5/8] Exécution du Script 12 (CheckV)..."
./00_scripts/12_hmm_verification.sh $SAMPLE > $LOG_DIR/12_hmm_verification.log 2>&1
echo "✅ 12 Terminé !"

# Lancement du 13
echo "⏳ [6/8] Exécution du Script 13 (CheckV)..."
./00_scripts/13_extract_phylogeny.sh $SAMPLE > $LOG_DIR/13_extract_phylogeny.log 2>&1
echo "✅ 13 Terminé !"

# Lancement du 14
echo "⏳ [7/8] Exécution du Script 14.1 (CheckV)..."
./00_scripts/14.1_mapping_gvdb_withoutf2.sh $SAMPLE > $LOG_DIR/14.1_mapping_gvdb_withoutf2.log 2>&1
echo "✅ 14.1 Terminé !"

# Lancement du 15
echo "⏳ [8/8] Exécution du Script 15 (CheckV)..."
./00_scripts/15_mapped_reads_assembly.sh $SAMPLE > $LOG_DIR/15_mapped_reads_assembly.log 2>&1
echo "✅ 15 Terminé !"

# Ajoute ici les suivants (11, 12, 13, etc.) sur le même modèle :
# echo "⏳ Exécution du Script 11..."
# ./00_scripts/11_final_integration.sh $SAMPLE > $LOG_DIR/11_integration.log 2>&1
# ...

echo "======================================================="
echo "🌅 TOUT EST TERMINÉ ! BON RÉVEIL !"
echo "======================================================="