nextflow.enable.types = true

process GET_EXISTING_BAMS {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    record(
        samplesheet: Path,
        genomesheet: Path,
        bam_dirs: List<Path>
    )

    output:
    file("existing_bams.tsv")

    script:
    """
    # Get list of strains/species
    awk '{
        if (NR == 1) {
            for (I=1;I<=NF;I++) {
                if (\$I == "strain") STRAIN_INDEX=I;
                else if (\$I == "species") SPECIES_INDEX=I;
            }
        } else {
            printf "%s %s\\n", \$STRAIN_INDEX, \$SPECIES_INDEX;
        }
    }' $samplesheet | \\
    sort | \\
    uniq > strains.txt

    # Get list of species/bam_dirs
    awk '{
        if (NR == 1) {
            for (I=1;I<=NF;I++) {
                if (\$I == "species") SPECIES_INDEX=I;
                else if (\$I == "bam_dir") BAM_INDEX=I;
            }
        } else {
            printf "%s %s\\n", \$SPECIES_INDEX, \$BAM_INDEX;
        }
    }' $genomesheet > bam_dirs.txt

    # Create associative array of species/bam_dirs
    declare -A BAM_DIRS
    for I in \$(cat bam_dirs.txt); do
        I = (\$I)
        BAM_DIRS["\${I[0]}"] = "\${I[1]}"
    done

    echo -e "strain\\tbam\\tbai" > existing_bams.tsv
    for I in \$(cat strains.txt); do
        I = (\${I})
        STRAIN = \${I[0]}
        SPECIES = \${I[1]}
        if [[ -v \$BAM_DIRS["\${SPECIES}"] ]]; then
            BAM_DIR = \$BAM_DIRS["\${SPECIES}"]
            if [[ -e \${BAM_DIR}/\${STRAIN}.bam ]]; then
                echo -e "\${STRAIN}\\t\${BAM_DIR}/\${STRAIN}.bam\\t\${BAM_DIR}/\${STRAIN}.bam.bai" >> existing_bams.tsv
            fi
        fi
    done
    """

    stub:
    """
    touch existing_bams.tsv
    """
}
