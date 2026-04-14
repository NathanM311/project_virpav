#!/bin/bash
set -e
# ------------------------------------------------------------------
# SCRIPT 04.1 : DÉCONTAMINATION TAXONOMIQUE (SANS BLANC)
# BUT : Créer des versions épurées (_no_contaminants.tsv) des tables
# ------------------------------------------------------------------

SAMPLE=${1:-"10-21D-AC16"}
BASE_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE"
TAX_DIR="${BASE_DIR}/02_results/05_taxonomy/${SAMPLE}"

# 🛑 Blacklist Complète (Basée sur ton audit visuel)
# Inclut : Humain, Kitome, Pollen (Betula), Insectes et Champignons terrestres
CONTAMINANTS="Homo sapiens|Homo|Escherichia|Staphylococcus|Streptococcus|Cutibacterium|Propionibacterium|Mycoplasma|Ralstonia|Bradyrhizobium|Acinetobacter|Malassezia|Enterobacter|Salmonella|Shigella|Brevundimonas|Sphingomonas|Betula|Insecta|Psychoda|Aspergillus|Fungi|Dikarya|Metazoa|Choanozoa"

echo "===================================================================="
echo "🧽 PURIFICATION DES DONNÉES POUR : $SAMPLE"
echo "===================================================================="

if [ ! -d "$TAX_DIR" ]; then
    echo "❌ ERREUR : Dossier de taxonomie introuvable."
    exit 1
fi

# On traite chaque fichier _CLEAN.tsv (mais pas ceux déjà traités)
for FILE in "${TAX_DIR}"/*_CLEAN.tsv; do
    # On évite de boucler sur un fichier déjà marqué "no_contaminants"
    if [[ "$FILE" == *"no_contaminants"* ]]; then continue; fi
    
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE")
        OUT_FILE="${FILE/.tsv/_no_contaminants.tsv}"
        
        echo "🔍 Traitement de : $BASENAME"
        
        # 1. On garde l'en-tête
        head -n 1 "$FILE" > "$OUT_FILE"
        
        # 2. On filtre les contaminants (grep -v -i -E)
        tail -n +2 "$FILE" | grep -v -i -E "$CONTAMINANTS" >> "$OUT_FILE"
        
        # --- Statistiques ---
        TOTAL=$(tail -n +2 "$FILE" | wc -l)
        KEPT=$(tail -n +2 "$OUT_FILE" | wc -l)
        REMOVED=$((TOTAL - KEPT))
        
        echo "   -> Transcrits totaux : $TOTAL"
        echo "   -> Signal marin conservé : 🌊 $KEPT"
        echo "   -> Bruit supprimé : 💥 $REMOVED"
        echo "   -> Nouveau fichier : $(basename "$OUT_FILE")"
        echo "------------------------------------------------"
    fi
done

echo "✅ Décontamination terminée avec succès !"
echo "===================================================================="