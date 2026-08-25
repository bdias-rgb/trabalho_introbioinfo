#!/bin/bash

#SBATCH --job-name=RNAseq_STAR
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err
#SBATCH --array=1-6%1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00


set -euo pipefail


#-------------------------LISTA DE AMOSTRAS-------------------------
 

SAMPLES=(
    SRR24678021
    SRR24678022
    SRR24678023
    SRR24677997
    SRR24677998
    SRR24677999
)

# A amostra correspondente a esta tarefa do array
SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID-1]}"

echo "======================================================"
echo "Job iniciado: $(date)"
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Amostra: $SAMPLE"
echo "CPUS: $SLURM_CPUS_PER_TASK"
echo "======================================================"

#-------------------------CRIAÇÃO DIRETÓRIOS-------------------------

BASE_DIR=${SLURM_SUBMIT_DIR:-$(pwd)}

mkdir -p \
    "$BASE_DIR/logs" \
    "$BASE_DIR/input" \
    "$BASE_DIR/fastq" \
    "$BASE_DIR/output" \
    "$BASE_DIR/reference" \
    "$BASE_DIR/tmp_star_index"


#-------------------------CARREGAR PACOTES-------------------------
module load sratoolkit
module load STAR/2.7.10b


#-------------------------DOWNLOAD DAS AMOSTRAS-------------------------

echo "======================================================"
echo "Baixando $SAMPLE"
echo "======================================================"

prefetch \
    -O "$BASE_DIR/input" \
    "$SAMPLE"



echo "======================================================"
echo "Convertendo $SAMPLE para FASTQ"
echo "======================================================"

SRA_FILE=$(find "$BASE_DIR/input/$SAMPLE" -name "*.sra" -print -quit)

if [[ -z "$SRA_FILE" ]]; then
    echo "ERRO: arquivo .sra não encontrado para $SAMPLE"
    exit 1
fi

fasterq-dump "$SRA_FILE" \
    --threads "$SLURM_CPUS_PER_TASK" \
    -O "$BASE_DIR/fastq"


echo "FASTQ gerado para $SAMPLE"


# Verificar se o fastq da amostra foi gerado

FASTQ1="$BASE_DIR/fastq/${SAMPLE}.fastq"

if [[ ! -f "$FASTQ1" ]]; then

    echo "ERRO: FASTQ não encontrado:"
    echo "$FASTQ1"

    echo "Arquivos FASTQ encontrados:"
    find "$BASE_DIR/fastq" -maxdepth 1 -type f -name "${SAMPLE}*" -print

    exit 1

fi


#-------------------------CRIAÇÃO DA PASTA DO INDEX E DOWNLOAD DOS ARQUIVOS DE REFERêNCIA-------------------------

STAR_INDEX_DIR="$BASE_DIR/reference/STAR_index" 

REFERENCE_FASTA_URL="https://ftp.ensembl.org/pub/release-115/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz"

REFERENCE_GTF_URL="https://ftp.ensembl.org/pub/release-115/gtf/mus_musculus/Mus_musculus.GRCm39.115.gtf.gz"


# Verificar se o index já existe, se não existir ele deve ser criado 

if [[ ! -d "$STAR_INDEX_DIR" ]] || \
   [[ ! -f "$STAR_INDEX_DIR/Genome" ]]; then

    echo "======================================================"
    echo "STAR index não encontrado."
    echo "Preparando referência..."
    echo "======================================================"

    mkdir -p "$BASE_DIR/reference"


    # ---------------- FASTA ----------------
    # Se o arquivo FASTA  de referência não existe na pasta, ele será baixado e descompactado
    REF_FA="$BASE_DIR/reference/$(basename "$REFERENCE_FASTA_URL")"

    if [[ ! -f "$REF_FA" ]]; then

        echo "Baixando FASTA..."

        wget -O "$REF_FA" \
            "$REFERENCE_FASTA_URL"

    fi


    REF_FA_UNZ="$BASE_DIR/reference/$(basename "${REF_FA%.gz}")"

    if [[ ! -f "$REF_FA_UNZ" ]]; then

        echo "Descompactando FASTA..."

        gunzip -c "$REF_FA" > "$REF_FA_UNZ"

    fi


    # ---------------- GTF ----------------
    # Se o arquivo GTF  de referência não existe na pasta, ele será baixado e descompactado

    REF_GTF="$BASE_DIR/reference/$(basename "$REFERENCE_GTF_URL")"

    if [[ ! -f "$REF_GTF" ]]; then

        echo "Baixando GTF..."

        wget -O "$REF_GTF" \
            "$REFERENCE_GTF_URL"

    fi


    REF_GTF_UNZ="$BASE_DIR/reference/$(basename "${REF_GTF%.gz}")"

    if [[ ! -f "$REF_GTF_UNZ" ]]; then

        echo "Descompactando GTF..."

        gunzip -c "$REF_GTF" > "$REF_GTF_UNZ"

    fi


    # ---------------- STAR INDEX ----------------

    mkdir -p "$STAR_INDEX_DIR"

    echo "======================================================"
    echo "Gerando STAR index"
    echo "======================================================"

    STAR \
        --runThreadN "$SLURM_CPUS_PER_TASK" \
        --runMode genomeGenerate \
        --genomeDir "$STAR_INDEX_DIR" \
        --genomeFastaFiles "$REF_FA_UNZ" \
        --sjdbGTFfile "$REF_GTF_UNZ" \
        --sjdbOverhang 100

else

    echo "======================================================"
    echo "STAR index já existe."
    echo "Usando:"
    echo "$STAR_INDEX_DIR"
    echo "======================================================"

fi

# ----------------RODAR O STAR----------------

OUT_DIR="$BASE_DIR/output/${SAMPLE}_STAR"

mkdir -p "$OUT_DIR"


echo "======================================================"
echo "Rodando STAR para $SAMPLE"
echo "======================================================"

STAR \
    --runThreadN "$SLURM_CPUS_PER_TASK" \
    --genomeDir "$STAR_INDEX_DIR" \
    --readFilesIn "$FASTQ1" \
    --outFileNamePrefix "$OUT_DIR/" \
    --outSAMtype BAM SortedByCoordinate \
    --quantMode TranscriptomeSAM GeneCounts



# Registros para o log 

echo "======================================================"
echo "STAR finalizado!"
echo "Amostra: $SAMPLE"
echo "Output: $OUT_DIR"
echo "Fim: $(date)"
echo "======================================================"
