process SOURMASH_SKETCH {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::sourmash=4.5.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sourmash:4.5.0--hdfd78af_0':
        'quay.io/biocontainers/sourmash:4.5.0--hdfd78af_0' }"

    input:
    tuple val(meta), path(sequence)
    val ksize
    val scaled
    val alphabet

    output:
    tuple val(meta), path("*.sig"), emit: signatures
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // required defaults for the tool to run, but can be overridden
    def args = task.ext.args ?: "protein --param-string 'k=${ksize},scaled=${scaled},abund'"
    def prefix = task.ext.prefix ?: "${meta.id}.${alphabet}.k${ksize}.scaled${scaled}"
    """
    sourmash sketch \\
        $args \\
        --merge '${prefix}' \\
        --output '${prefix}.sig.gz' \\
        $sequence

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sourmash: \$(echo \$(sourmash --version 2>&1) | sed 's/^sourmash //' )
    END_VERSIONS
    """
}
