process SOURMASH_MULTISEARCH {
    tag "${meta.id}.${alphabet}.k${ksize}.scaled${scaled}"
    label 'process_low'

    conda "bioconda::sourmash=4.5.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sourmash:4.5.0--hdfd78af_0':
        'quay.io/biocontainers/sourmash:4.5.0--hdfd78af_0' }"

    input:
    tuple val(alphabet), val(ksize), val(scaled), val(meta), path(query), path(databases)

    output:
    tuple val(alphabet), val(ksize), val(scaled), val(meta), path("*.csv"), emit: signatures
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // required defaults for the tool to run, but can be overridden
    def args = task.ext.args ?: "--threshold 0.0001 --alphabet --no-dna --ksize $ksize --num-results 10 --add-kmer-stats"
    def prefix = task.ext.prefix ?: "${meta.id}.${alphabet}.k${ksize}.scaled${scaled}"
    """
    sourmash-multisearch.py \\
        $args \\
        --query $query \\
        --databases $databases \\
        --output-dir .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sourmash: \$(echo \$(sourmash --version 2>&1) | sed 's/^sourmash //' )
    END_VERSIONS
    """
}
