#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { RUN_COPYKAT }   from './modules/run_copykat/main.nf'
include { ANNOTATE_H5AD } from './modules/annotate_h5ad/main.nf'
include { CONCAT_H5ADS }  from './modules/concat_h5ads/main.nf'

def helpMessage() {
    log.info """
    nf-austin/copykat -- CopyKAT CNV calling, ploidy prediction and CIN scoring

    Usage, samplesheet (recommended; this is what Seqera Platform launches with):
      nextflow run main.nf -profile docker --input samplesheet.csv --outdir results

      samplesheet.csv columns: sample, h5ad

    Usage, ad-hoc glob:
      nextflow run main.nf -profile docker --h5ad_dir "data/*.h5ad"

    Required (one of):
      --input         Samplesheet CSV.
      --h5ad_dir      Glob matching .h5ad files.

    Common options:
      --outdir        Output directory (default: ${params.outdir}).
      --genome        Genome assembly: hg20, hg19 or mm10 (default: ${params.genome}).
      --cell_line     "yes" for cell lines, "no" for primary tissue (default: ${params.cell_line}).
      --id_type       "S" for gene symbols, "E" for Ensembl IDs (default: ${params.id_type}).

    On a cluster, add `-profile slurm,singularity --slurm_queue <partition>` and use
    absolute paths. See the README for the HPC notes.
    """.stripIndent()
}

/**
 * Resolve one samplesheet entry to a file.
 *
 * A relative entry is resolved against the samplesheet's OWN directory first,
 * which is what someone editing that sheet expects. Nextflow's default is the
 * launch directory, and on Seqera Platform the launch directory is the work
 * directory -- so a relative path there silently resolves somewhere unrelated.
 * Falls back to launch-dir resolution, and only then reports the entry missing.
 */
def resolveInput(path, sheet_dir, row_num) {
    // Absolute POSIX path, or a remote URI (s3://, gs://, az://): take as-is.
    if (path.startsWith('/') || path ==~ /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/.*/) {
        return file(path, checkIfExists: true)
    }
    def beside_sheet = sheet_dir.resolve(path)
    if (beside_sheet.exists()) {
        return beside_sheet
    }
    def from_launch = file(path)
    if (from_launch.exists()) {
        return from_launch
    }
    error "Samplesheet row ${row_num}: h5ad not found as '${beside_sheet}' (relative to the samplesheet) nor as '${from_launch}' (relative to the launch directory). Use an absolute path."
}

/**
 * Turn samplesheet rows into (sample_id, h5ad) tuples.
 *
 * Validated eagerly over the fully-read row list rather than inside a channel
 * closure: errors raised in a closure are lazy -- they never fire under
 * -preview, and in a real run they surface only once the channel is consumed.
 * A bad samplesheet must fail at launch, before Platform provisions compute.
 */
def buildSamples(rows, sheet_dir) {
    if (!rows) {
        error "Samplesheet is empty: ${params.input}"
    }
    def required = ['sample', 'h5ad']
    def missing = required.findAll { c -> !rows[0].containsKey(c) }
    if (missing) {
        error "Samplesheet is missing column(s): ${missing.join(', ')}. Found: ${rows[0].keySet().join(', ')}"
    }

    def seen = [] as Set
    return rows.withIndex().collect { row, idx ->
        def sample_id = row.sample?.trim()
        if (!sample_id) {
            error "Samplesheet row ${idx + 1} has an empty 'sample' value"
        }
        if (!seen.add(sample_id)) {
            error "Samplesheet has a duplicate sample id: '${sample_id}'. Sample ids become output paths and must be unique."
        }
        def h5ad = row.h5ad?.trim()
        if (!h5ad) {
            error "Samplesheet row ${idx + 1} ('${sample_id}') has an empty 'h5ad' value"
        }
        tuple(sample_id, resolveInput(h5ad, sheet_dir, idx + 1))
    }
}

workflow {
    if (params.help) {
        helpMessage()
        return
    }

    if (params.input && params.h5ad_dir) {
        error "Use either --input (samplesheet) or --h5ad_dir (glob), not both."
    }
    if (!params.input && !params.h5ad_dir) {
        error "No input given. Provide --input samplesheet.csv or --h5ad_dir \"data/*.h5ad\". Run with --help for details."
    }

    if (params.input) {
        def sheet = file(params.input, checkIfExists: true)
        def rows = sheet.splitCsv(header: true, strip: true)
        ch_samples = channel.fromList(buildSamples(rows, sheet.parent))
    }
    else {
        ch_samples = channel.fromPath(params.h5ad_dir, checkIfExists: true)
            .map { f -> tuple(f.baseName.replaceFirst(/_annotated$/, ''), f) }
    }

    log.info """
    P I P E L I N E   nf-austin/copykat
    ===================================
    input     : ${params.input ?: params.h5ad_dir}
    genome    : ${params.genome}
    cell_line : ${params.cell_line}
    id_type   : ${params.id_type}
    outdir    : ${params.outdir}
    """.stripIndent()

    RUN_COPYKAT(
        ch_samples,
        params.id_type,
        params.cell_line,
        params.ngene_chr,
        params.low_dr,
        params.up_dr,
        params.win_size,
        params.distance,
        params.ks_cut,
        params.genome
    )

    ch_annotate_in = ch_samples.join(RUN_COPYKAT.out.copykat_dir)

    ANNOTATE_H5AD(
        ch_annotate_in
    )

    ANNOTATE_H5AD.out.h5ad
        | map { _sample_id, h5ad -> h5ad }
        | collect
        | set { ch_all_h5ads }

    CONCAT_H5ADS(
        ch_all_h5ads
    )
}
