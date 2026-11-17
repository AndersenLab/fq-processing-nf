nextflow.enable.types = true

process SUBSET_READS {
    tag "${meta.id}"
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    record (
        meta: Map,
        fastqs: List<Path>
    )
    subsample: Integer

    output:
    record (
        meta: meta,
        fastqs: files("${meta.id}*.subset.fq.gz").toList().toSorted(),
    )

    script:
    def command = fastqs[0].getName().endsWith("gz") ? 'zcat' : 'cat'

    if (meta.single_end) {
        """
        # Check if on a Mac
        if [ \$(uname) == "Darwin" ] && [ "${command}" == "zcat" ]; then
            COMMAND="gunzip -c"
        else
            COMMAND="${command}"
        fi
        
        \${COMMAND} ${fastqs[0]} | head -n \$(expr ${subsample} \\* 4) | gzip -c > ${meta.id}.subset.fq.gz
        """
    } else {
        """
        # Check if on a Mac
        if [ \$(uname) == "Darwin" ] && [ "${command}" == "zcat" ]; then
            COMMAND="gunzip -c"
        else
            COMMAND="${command}"
        fi

        # For each fastq file (could be single or paired end), take the first "subsample" number of reads (4 lines per read)
        READS=(${fastqs})
        for I in \$(seq 0 1 \$(expr \${#READS[*]} - 1)); do
            \${COMMAND} \${READS[\${I}]} | head -n \$(expr ${subsample} \\* 4) | gzip -c > ${meta.id}_\$(expr \${I} + 1)R.subset.fq.gz
        done
        """
    }

    stub:
    if (meta.single_end) {
        """
        echo "" | gzip -c > ${meta.id}.subset.fq.gz
        """
    } else {
        """
        READS=(${fastqs})
        for I in \$(seq 0 1 \$(expr \${#READS[*]} - 1)); do
            echo "" | gzip -c > ${meta.id}_\${I}R.subset.fq.gz
        done
        """
    }
}