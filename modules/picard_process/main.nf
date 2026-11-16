nextflow.enable.types = true

process PICARD_PROCESS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'community.wave.seqera.io/library/picard:3.4.0--e9963040df0a9bf6'

    input:
    record(
        meta: Map,
        bam: Path?,
        bai: Path?,
        stats: Path?
    )

    stage:
    stageAs(bam, "unprocessed/*")
    stageAs(bai, "unprocessed/*")

    output:
    record(
        meta: meta,
        bam: file("${meta.id}.bam"),
        bai: file("${meta.id}.bai"),
        stats: file("${meta.id}.MarkDuplicates.metrics.txt")
    )

    topic:
    record(tool: "picard", version:eval("picard AddOrReplaceReadGroups --version 2>&1 | grep -o 'Version:.*' | cut -f2- -d:")) >> 'versions'

    script:
    def args = task.ext.args        ?: ''
    def args2 = task.ext.args2      ?: ''
    def prefix = task.ext.prefix    ?: "${meta.id}"
    def avail_mem = (task.memory.toMega() * 0.8).intValue()

    """
    picard \\
        -Xmx${avail_mem}M \\
        AddOrReplaceReadGroups \\
        $args \\
        --INPUT ${bam} \\
        --OUTPUT ${prefix}.rg.bam

    picard \\
        -Xmx${avail_mem}M \\
        MarkDuplicates \\
        $args2 \\
        --INPUT ${prefix}.rg.bam \\
        --OUTPUT ${prefix}.bam \\
        --METRICS_FILE ${prefix}.MarkDuplicates.metrics.txt

    rm ${prefix}.rg.bam
    """

    stub:
    def prefix = task.ext.prefix    ?: "${meta.id}"
    """
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    touch ${prefix}.MarkDuplicates.metrics.txt
    """
}
