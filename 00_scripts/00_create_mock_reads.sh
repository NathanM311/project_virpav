#!/bin/bash
# ------------------------------------------------------------------
# CRÉATION D'UN MOCK METATRANSCRIPTOME (SIMULATION DE READS ILLUMINA)
# ------------------------------------------------------------------

OUT_DIR="/mnt/MERSEA/morandi241/project_virpav/ANALYSIS_V3_PROPRE/01_data/raw_data/MOCK_SAMPLE"
mkdir -p $OUT_DIR
cd $OUT_DIR

echo "🔄 1. Préparation de l'environnement (wgsim & entrez-direct)..."
source $HOME/miniconda3/etc/profile.d/conda.sh
conda create -n env_mock -c bioconda -c conda-forge wgsim entrez-direct -y
conda activate env_mock

# Fonction pour télécharger un génome et générer des reads FASTQ
# Arguments: Accession_NCBI, Nom, Nombre_de_paires_de_reads
simulate_reads() {
    ACCESSION=$1
    NAME=$2
    N_READS=$3
    
    echo "📥 Téléchargement de $NAME ($ACCESSION)..."
    efetch -db nuccore -id $ACCESSION -format fasta > ${NAME}.fasta
    
    echo "🧬 Génération de $N_READS paires de reads Illumina pour $NAME..."
    # -N : nb de reads | -1/-2 : taille des reads (150bp) | -d : taille de l'insert (250bp) | -e : taux d'erreur (0.01)
    wgsim -N $N_READS -1 150 -2 150 -d 250 -e 0.01 ${NAME}.fasta ${NAME}_R1.fq ${NAME}_R2.fq > /dev/null
    
    rm ${NAME}.fasta
}

echo "===================================================================="
echo "🧪 GÉNÉRATION DES DONNÉES SYNTHÉTIQUES (1 MILLION DE READS)"
echo "===================================================================="

# 1. Bruit de fond de l'Hôte (Emiliania huxleyi)
simulate_reads "NC_005332.1" "Ehux_Mito" 150000
simulate_reads "NC_007288.1" "Ehux_Plastid" 400000

# 2. Virus d'algues (Cibles principales)
simulate_reads "NC_007346.1" "EhV86_Virus" 250000
simulate_reads "NC_010191.2" "OtV5_Virus" 50000

# 3. Écosystème (Bactérie + Phage + Virophage)
simulate_reads "NC_007205.1" "Pelagibacter_Bact" 100000
simulate_reads "NC_000866.4" "T4_Phage" 40000
simulate_reads "NC_011132.1" "Sputnik_Virophage" 9000

# 4. Contaminant Technique
simulate_reads "NC_001422.1" "PhiX174" 1000

echo "===================================================================="
echo "🌪️ FUSION DES READS (Création de l'échantillon final)"
echo "===================================================================="
# On concatène tous les R1 ensemble, et tous les R2 ensemble
cat *_R1.fq > MOCK_SAMPLE_R1.fastq
cat *_R2.fq > MOCK_SAMPLE_R2.fastq

# Nettoyage des fichiers intermédiaires
rm *_R1.fq *_R2.fq

echo "📦 Compression des fichiers..."
gzip MOCK_SAMPLE_R1.fastq
gzip MOCK_SAMPLE_R2.fastq

conda deactivate

echo "✅ ÉCHANTILLON MOCK_SAMPLE CRÉÉ AVEC SUCCÈS !"
echo "📁 Fichiers disponibles dans : $OUT_DIR"
echo "👉 Prochaine étape : Lancer Trinity sur ces deux fichiers FASTQ."
