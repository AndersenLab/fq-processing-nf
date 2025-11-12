process SPECIES_STATS {
    tag "${meta.id} ${meta.species}"
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    tuple val(meta), path(stats)

    output:
    tuple val(meta), path("${meta.id}_${meta.species}.stats") , emit: stats

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk -v ID="${meta.id}" -v SPECIES="${meta.species}" '{
        # Skip the header line
        if (NR > 1) {
            # Count mapped reads
            MAPPED=MAPPED+\$3;
            # Count unmapped reads
            UNMAPPED=UNMAPPED+\$4;
        }
    } END {
        # Print the sample, species, and percent of mapped reads with a header line
        printf "ID\\tSPECIES\\tPERCENT_MAPPING\\n%s\\t%s\\t%f\\n", ID, SPECIES, MAPPED / (MAPPED + UNMAPPED);
    }' ${stats} > ${meta.id}_${meta.species}.stats
    """

    stub:
    """
    touch ${meta.id}_${meta.species}.stats
    """
}