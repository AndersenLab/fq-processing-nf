process COVERAGE {

    container "quay.io/biocontainers/mosdepth:0.3.3--h37c5b7d_2"

    array 20
    
    label 'coverage'

    errorStrategy 'retry'
    time { 4.hour * task.attempt }
    cpus = { 1 * task.attempt }
    memory = { 4.GB * task.attempt }

    input:
        tuple val(meta), path(bam), path(bai)

    output:
        tuple val(meta), path("${meta.id}.coverage"), emit: coverage
        path "versions.yml",                          emit: versions

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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mosdepth: \$(mosdepth -h | head -n 1 | cut -f2 -d" ")
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.coverage

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mosdepth: \$(mosdepth -h | head -n 1 | cut -f2 -d" ")
    END_VERSIONS
    """
}