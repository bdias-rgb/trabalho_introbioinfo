# trabalho_introbioinfo
Trabalho final disciplina GA-055/2026


## Pré-processamento e alinhamento de RNA-seq com STAR

Este script Bash implementa um pipeline automatizado para baixar e alinhamento de dados de RNA-seq, executado em um cluster HPC utilizando o gerenciador de tarefas Slurm.

O pipeline realiza as seguintes etapas:

1. Download das amostras de RNA-seq a partir do NCBI Sequence Read Archive (SRA) utilizando o SRA Toolkit.
2. Conversão dos arquivos SRA para o formato FASTQ
3. Download do genoma de referência de camundongo (*Mus musculus*, GRCm39) e da anotação gênica correspondente do Ensembl.
4. Construção do índice do genoma utilizando o STAR, caso o índice ainda não exista.
5. Alinhamento dos reads de RNA-seq ao genoma de referência utilizando o STAR.

### Referência utilizada

- Organismo: *Mus musculus*
- Genoma: GRCm39
- Anotação gênica: Ensembl release 115
- Alinhador: STAR v2.7.10b
- SRA Toolkit: download e conversão dos dados do SRA

### Execução no cluster

O pipeline foi configurado para execução como um Slurm job array, permitindo o processamento independente de cada amostra.
