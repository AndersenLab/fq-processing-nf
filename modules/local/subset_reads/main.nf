process SUBSET_READS {
    tag "${meta.id}"
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    tuple val(meta), path(reads)
    val subsample

    output:
    tuple val(meta), path("*.subset.fq.gz") , emit: subset

    when:
    task.ext.when == null || task.ext.when

    script:
    def command = reads[0].toString().endsWith("gz") ? 'zcat' : 'cat'
    """
    # Check if on a Mac
    if [ \$(uname) == "Darwin" ] && [ "${command}" == "zcat" ]; then
        COMMAND="gunzip -c"
    else
        COMMAND="${command}"
    fi

    # For each fastq file (could be single or paired end), take the first "subsample" number of reads (4 lines per read)
    READS=(${reads})
    for I in \$(seq 0 1 \$(expr \${#READS[*]} - 1)); do
        \${COMMAND} \${READS[\${I}]} | head -n \$(expr ${subsample} \\* 4) | gzip -c > ${meta.id}_\$(expr \${I} + 1)R.subset.fq.gz
    done
    """

    stub:
    """
    READS=(${reads})
    for I in \$(seq 0 1 \$(expr \${#READS[*]} - 1)); do
        echo "" | gzip -c > ${meta.id}_\${I}R.subset.fq.gz
    done
    """
}