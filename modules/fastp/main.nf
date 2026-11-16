nextflow.enable.types = true

process FASTP {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "community.wave.seqera.io/library/fastp:1.0.1--c8b87fe62dcc103c"

    input:
    record (
        meta: Map,
        fastqs: List<Path>
    )

    output:
    record (
        meta: meta,
        fastqs: file("${meta.id}*.fastp.fq.gz"),
    )

    topic:
    record(tool:"fastp", version:eval("fastp --version 2>&1 | sed -e 's/fastp //g'")) >> 'versions'

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def out_fq1 = meta.single_end ? "--out1 ${prefix}.fastp.fq.gz" : "--out1 ${prefix}_1R.fastp.fq.gz"
    def out_fq2 = meta.single_end ? '' : "--out2 ${prefix}_2R.fastp.fq.gz"
    if (meta.single_end) {
        """
        fastp \\
            --in1 ${fastqs[0]} \\
            $out_fq1 \\
            --thread $task.cpus \\
            $args \\
            2>| >(tee ${prefix}.fastp.log >&2)
        """
    } else {
        """
        fastp \\
            --in1 ${fastqs[0]} \\
            --in2 ${fastqs[1]} \\
            $out_fq1 \\
            $out_fq2 \\
            --thread $task.cpus \\
            --detect_adapter_for_pe \\
            $args \\
            2>| >(tee ${prefix}.fastp.log >&2)
        """
    }

    stub:
    def prefix              = task.ext.prefix ?: "${meta.id}"
    def touch_reads         = meta.single_end ? "echo '' | gzip > ${prefix}.fastp.fq.gz" : "echo '' | gzip > ${prefix}_1R.fastp.fq.gz ; echo '' | gzip > ${prefix}_2R.fastp.fq.gz"
    """
    $touch_reads
    touch "${prefix}.fastp.log"
    """
}
