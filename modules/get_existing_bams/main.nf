nextflow.enable.types = true

process GET_EXISTING_BAMS {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    record(
        genome: String,
        bam_dir: Path,
        samplesheet: Path
    )

    output:
    file("existing_bams_${genome}.tsv")

    script:
    """
    # Get list of strains/species
    (head -n 1 $samplesheet; grep -w $genome $samplesheet;) | \\
    awk '{
        if (NR == 1) {
            for (I=1;I<=NF;I++) {
                if (\$I == "strain" ) STRAIN_INDEX=I;
            }
        } else {
            printf "%s\\n", \$STRAIN_INDEX;
        }
    }' | \\
    sort | \\
    uniq > strains.csv

    echo -e "strain\\tbam\\tbai" >> existing_bams_${genome}.tsv
    for STRAIN in \$(cat strains.csv); do
        if [[ -e $bam_dir/\$STRAIN.bam ]]; then
            echo -e "\${STRAIN}\\t${bam_dir}/\${STRAIN}.bam\\t${bam_dir}/\${STRAIN}.bam.bai" >> existing_bams_${genome}.tsv
        fi
    done
    """

    stub:
    """
    echo -e "strain\\tbam\\tbai" >> existing_bams_${genome}.tsv
    """
}
