//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fasta ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.fasta).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Fasta file does not exist!\n${row.fasta}"
    }
    fastq_meta = [ meta, [ file(row.fasta) ] ]
    return fastq_meta
}
