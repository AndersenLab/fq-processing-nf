nextflow.enable.types = true

process MERGE_BAM_LIST {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    bam_tsvs: Bag<Path>

    output:
    file("existing_bams.tsv")

    script:
    def sorted_files = bam_tsvs.toList().toSorted { f -> f.name }.join(' ')
    """
    echo -e "strain\\tbam\\tbai" >> existing_bams.tsv
    for I in $sorted_files; do
        tail -n +2 \$I >> existing_bams.tsv
    done
    """

    stub:
    """
    echo -e "strain\\tbam\\tbai" >> existing_bams.tsv
    """
}
