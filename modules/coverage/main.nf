nextflow.enable.types = true

process COVERAGE {
    tag "$meta.id"
    label 'process_low'

    container "quay.io/biocontainers/mosdepth:0.3.3--h37c5b7d_2"


    input:
    record(
        meta: Map,
        bam: Path,
        bai: Path
    )

    output:
    record(
        meta: meta,
        bam: file("${meta.id}.bam"),
        bai: file("${meta.id}.bai"),
        coverage: file("${meta.id}.coverage")
    )

    topic:
    record(tool: "mosdepth", version: eval("mosdepth -h | head -n 1 | cut -f2 -d' '")) >> 'versions'
    
    script:
    """
    mosdepth --threads ${task.cpus} ${meta.id} ${bam}
    awk -v STRAIN="${meta.id}" 'BEGIN{N=0} \
                               { if (NR > 1){N=N+1; CHROMS[N]=\$1; COVERAGE[\$1]=\$4;}} \
                               END{printf "strain\\tcoverage"; for (I=1;I<N;I++) printf "\\t%s", CHROMS[I]; printf "\\n"; \
                                   printf "%s\\t%f", STRAIN, COVERAGE[CHROMS[N]]; for (I=1;I<N;I++) printf "\\t%s", COVERAGE[CHROMS[I]]; \
                                   printf "\\n";}' ${meta.id}.mosdepth.summary.txt > ${meta.id}.coverage
    rm ${meta.id}.mosdepth*
    rm ${meta.id}.per-base*
    """

    stub:
    """
    touch ${meta.id}.coverage
    """
}