#!/bin/bash
# ============================================================
# PROKKA + PANAROO AUTOMATION PIPELINE
# Description: Automates Prokka annotation and Panaroo pangenome analysis
# Notes:
# - Adjust GENUS, SPECIES, base_dir, and reference annotation file according to your pathogen
# - This script is fully commented for reproducibility
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
ref_gff="$base_dir/annotations/reference.gff3"          # Optional reference annotation file

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
# --

