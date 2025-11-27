#!/bin/bash
# ============================================================
# PROKKA + PANAROO AUTOMATION PIPELINE
# Description: Automates Prokka annotation and Panaroo pangenome analysis
# Notes:
# - Adjust GENUS, SPECIES, base_dir, and reference annotation file according to your pathogen
# ============================================================

set -euo pipefail    # Exit on error, unset variables are errors, fail on pipe errors
IFS=$'\n\t'          # Handle filenames with spaces/tabs
timestamp=$(date +'%Y-%m-%d_%H-%M-%S')  # Timestamp for logging

# ============================================================
# 1. User Adjustable Parameters
# ============================================================
base_dir="/home/maa/Project_ESKAPE/P_aeruginosa/Egypt"   # Path to pathogen assemblies
GENUS="Pseudomonas"                                      # Genus of the pathogen
SPECIES="aeruginosa"                                     # Species of the pathogen
THREADS=4                                                # Number of CPU threads
ref_gff="$base_dir/annotations/reference.gff3"          # Reference annotation file

# ============================================================
# 2. Directory Setup
# ============================================================
input_dir="$base_dir/assembly"           # Input assembly FASTA files
annotation_dir="$base_dir/annotations"   # Output from Prokka annotation
output_dir="$base_dir/panaroo_output"    # Panaroo output folder
log_dir="$base_dir/logs"                 # Logs folder
main_log="$log_dir/pipeline_${timestamp}.log"

# Create directories if they don't exist
mkdir -p "$annotation_dir" "$output_dir" "$log_dir"

echo "=== PROKKA + PANAROO PIPELINE STARTED at $(date) ===" | tee -a "$main_log"

# ============================================================
# 3. Reference Annotation Check
# ============================================================
if [[ ! -f "$ref_gff" ]]; then
    echo "[WARNING] Reference annotation file not found. Consider adding one matching your pathogen." | tee -a "$main_log"
else
    echo "[INFO] Reference annotation found: $ref_gff" | tee -a "$main_log"
fi

# ============================================================
# 4. Prokka Annotation
# ============================================================
# Prokka Flags Explanation:
# --outdir      : Directory for Prokka output for each genome
# --prefix      : Prefix for all output files (usually sample ID)
# --kingdom     : Specify kingdom, e.g., Bacteria
# --genus       : Specify genus for accurate gene annotation
# --species     : Specify species for accurate gene annotation
# --usegenus    : Use genus-specific database to improve annotation
# --compliant   : Generate GenBank-compliant files
# --force       : Overwrite output directory if it exists
# --cpus        : Number of CPU threads
# Genome file   : The cleaned FASTA of contigs

for genome in "$input_dir"/*contigs.fasta; do
    if [ -f "$genome" ]; then
        srr_id=$(basename "$(dirname "$genome")")  # Sample name based on folder
        name="$srr_id"
        outdir="$annotation_dir/$name"
        mkdir -p "$outdir"

        echo "[INFO] Cleaning contig names for $name..." | tee -a "$main_log"
        # Rename contigs to avoid Panaroo errors: >contig_1, >contig_2, ...
        cleaned_genome="$input_dir/${name}_clean.fasta"
        awk '/^>/{print ">contig_" ++i; next}{print}' "$genome" > "$cleaned_genome"

        echo "[INFO] Annotating $name as ${GENUS} ${SPECIES}..." | tee -a "$main_log"
        prokka \
            --outdir "$outdir" \
            --prefix "$name" \
            --kingdom Bacteria \
            --genus "$GENUS" \
            --species "$SPECIES" \
            --usegenus \
            --compliant \
            --force \
            --cpus "$THREADS" \
            "$cleaned_genome" >> "$main_log" 2>&1

        echo "[INFO] Finished annotation for $name" | tee -a "$main_log"
        echo "[INFO] Annotated files stored in: $outdir" | tee -a "$main_log"
    fi
done

echo "[INFO] All Prokka annotations completed." | tee -a "$main_log"

# ============================================================
# 5. Collect GFF Files for Panaroo
# ============================================================
# Panaroo requires all genome annotations in GFF format
# This collects all Prokka-generated GFF files
gff_list=()
while IFS= read -r -d '' gff; do
    gff_list+=("$gff")
done < <(find "$annotation_dir" -type f -name "*.gff" -print0)

if [ ${#gff_list[@]} -eq 0 ]; then
    echo "[ERROR] No GFF files found in $annotation_dir!" | tee -a "$main_log"
    exit 1
fi

echo "[INFO] Found ${#gff_list[@]} GFF files for Panaroo." | tee -a "$main_log"

# ============================================================
# 6. Panaroo Pangenome Analysis
# ============================================================
# Panaroo Flags Explanation:
# -i                 : Input GFF files
# -o                 : Output folder
# --clean-mode strict: Remove low-quality or inconsistent genes
# --remove-invalid-genes: Filter genes missing essential info
# --merge_paralogs   : Merge highly similar paralogs
# -a core            : Output core genome alignment
# --aligner mafft    : Use MAFFT for gene alignment
# --core_threshold 0.95: Genes present in ≥95% of genomes are core
# -t                 : Number of CPU threads

echo "[INFO] Starting Panaroo analysis..." | tee -a "$main_log"

panaroo -i "${gff_list[@]}" \
    -o "$output_dir" \
    --clean-mode strict \
    --remove-invalid-genes \
    --merge_paralogs \
    -a core \
    --aligner mafft \
    --core_threshold 0.95 \
    -t "$THREADS" >> "$main_log" 2>&1

echo "[INFO] Panaroo analysis completed successfully. Results saved to $output_dir" | tee -a "$main_log"

# ============================================================
# 7. Pipeline Completion
# ============================================================
echo "=== PIPELINE COMPLETED SUCCESSFULLY at $(date) ===" | tee -a "$main_log"
