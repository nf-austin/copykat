#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { RUN_COPYKAT }   from './modules/run_copykat/main.nf'
include { ANNOTATE_H5AD } from './modules/annotate_h5ad/main.nf'
include { CONCAT_H5ADS }  from './modules/concat_h5ads/main.nf'

workflow {
    channel.fromPath(params.h5ad_dir)
        | map { f -> tuple(f.baseName.replaceFirst(/_annotated$/, ''), f) }
        | set { ch_samples }

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

    ANNOTATE_H5AD(ch_annotate_in)

    ANNOTATE_H5AD.out.h5ad
        | map { _sample_id, h5ad -> h5ad }
        | collect
        | set { ch_all_h5ads }

    CONCAT_H5ADS(ch_all_h5ads)
}