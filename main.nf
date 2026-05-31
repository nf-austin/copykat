#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { BUILD_COPYKAT_SIF } from './modules/build_copykat_sif/main.nf'
include { RUN_COPYKAT }       from './modules/run_copykat/main.nf'
include { ANNOTATE_H5AD }     from './modules/annotate_h5ad/main.nf'
include { CONCAT_H5ADS }      from './modules/concat_h5ads/main.nf'

workflow {
    // Build the Singularity image on first run; skip if it already exists.
    if (!file(params.copykat_sif).exists()) {
        BUILD_COPYKAT_SIF()
        sif_ch = BUILD_COPYKAT_SIF.out.ready
    } else {
        sif_ch = Channel.value(true)
    }

    channel.fromPath(params.h5ad_dir)
        | map { f -> tuple(f.baseName.replaceFirst(/_annotated$/, ''), f) }
        | set { ch_samples }

    // Gate each sample on sif_ch so RUN_COPYKAT never starts before the image exists.
    ch_samples
        .combine(sif_ch)
        .map { id, h5ad, _ready -> tuple(id, h5ad) }
        | set { ch_gated }

    RUN_COPYKAT(
        ch_gated,
        Channel.value(file("${projectDir}/modules/run_copykat/run_copykat.R")),
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

    ANNOTATE_H5AD(ch_annotate_in)

    ANNOTATE_H5AD.out.h5ad
        | map { _sample_id, h5ad -> h5ad }
        | collect
        | set { ch_all_h5ads }

    CONCAT_H5ADS(ch_all_h5ads)
}