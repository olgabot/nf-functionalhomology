/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowFunctionalhomology.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

ch_ksizes = Channel.from(params.ksize_min..params.ksize_max)
ch_scaleds = Channel.from(params.scaled_min..params.scaled_max)
ch_alphabets = Channel.from(params.alphabets?.toString()?.tokenize(","))
// n_ksizes = ch_ksizes.count().collect()
// n_scaleds = ch_scaleds.count().collect()
// n_alphabets = ch_alphabets.count().collect()
// println("n_ksizes: ${n_ksizes}")
// println("n_scaleds: ${n_scaleds}")
// println("n_alphabets: ${n_alphabets}")

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SOURMASH_SKETCH             } from '../modules/local/sourmash/sketch/main'
include { SOURMASH_MULTISEARCH        } from '../modules/local/sourmash/multisearch/main'


//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow FUNCTIONALHOMOLOGY {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    // n_inputs = INPUT_CHECK.out.reads.count().valueOf()
    // println("n_inputs: ${n_inputs}")
    // n_iterations = n_ksizes * n_scaleds * n_alphabets * n_inputs
    // println("Total expected number of sketches: ${n_iterations}")
    // ch_ksizes.view()
    // ch_scaleds.view()
    // ch_alphabets.view()

    // reads_sketch_parameters = INPUT_CHECK.out.reads
    //     .combine(ch_ksizes)
    //     .combine(ch_scaleds)
    //     .combine(ch_alphabets)

    // reads_sketch_parameters.view()
    //
    // MODULE: Run Sourmash Sketch
    //
    SOURMASH_SKETCH (
        INPUT_CHECK.out.reads,
        ch_alphabets,
        ch_ksizes,
        ch_scaleds
    )
    ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions.first())

    ch_signatures_by_sketch_params = SOURMASH_SKETCH.out.signatures
        .groupTuple(by: [0, 1, 2])

    // ch_signatures_by_sketch_params.view()

    ch_query_with_dbs = SOURMASH_SKETCH.out.signatures.join(
        ch_signatures_by_sketch_params, by: [0, 1, 2])
    // ch_query_with_dbs.view()

    // ch_query_with_dbs_transpose = SOURMASH_SKETCH.out.signatures.transpose(
    //     ch_signatures_by_sketch_params, by: [0, 1, 2])
    // ch_query_with_dbs_transpose.view()
    // ch_query_with_dbs.transpose().view()

    ch_query_with_dbs_unnested = ch_query_with_dbs.map{
        tuple(it[0], it[1], it[2], it[3], it[4], it[6])
    }
    ch_query_with_dbs_unnested_query_removed = ch_query_with_dbs_unnested.map{
        alpha, k, scaled, meta, query, dbs ->
        tuple(alpha, k, scaled, meta, query, dbs.findAll{ it != query })
    }
    // ch_query_with_dbs_unnested.view()

    SOURMASH_MULTISEARCH(ch_query_with_dbs_unnested_query_removed)

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: Run FastQC
    //
    // FASTQC (
    //     INPUT_CHECK.out.reads
    // )
    // ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    // CUSTOM_DUMPSOFTWAREVERSIONS (
    //     ch_versions.unique().collectFile(name: 'collated_versions.yml')
    // )

    // //
    // // MODULE: MultiQC
    // //
    // workflow_summary    = WorkflowFunctionalhomology.paramsSummaryMultiqc(workflow, summary_params)
    // ch_workflow_summary = Channel.value(workflow_summary)

    // methods_description    = WorkflowFunctionalhomology.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    // ch_methods_description = Channel.value(methods_description)

    // ch_multiqc_files = Channel.empty()
    // ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    // ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    // ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    // ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    // MULTIQC (
    //     ch_multiqc_files.collect(),
    //     ch_multiqc_config.toList(),
    //     ch_multiqc_custom_config.toList(),
    //     ch_multiqc_logo.toList()
    // )
    // multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
