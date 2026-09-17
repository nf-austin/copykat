process RUN_COPYKAT {
    tag { sample_id }
    publishDir { "${params.outdir}/${sample_id}_copykat" }, mode: 'copy'

    // No `conda` directive on purpose: CopyKAT is not packaged on conda-forge or
    // Bioconda -- it installs from GitHub -- so environment.yml here cannot
    // provide it and `-profile conda` cannot run this process. It resolves
    // through the container only. The environment.yml is kept as the record of
    // the surrounding R stack that the image is built on.
    container params.copykat_container

    input:
    tuple val(sample_id), path(h5ad)
    val id_type
    val cell_line
    val ngene_chr
    val low_dr
    val up_dr
    val win_size
    val distance
    val ks_cut
    val genome

    output:
    tuple val(sample_id), path("copykat_out"), emit: copykat_dir

    script:
    // Scripts live in bin/ and are called bare: Nextflow prepends
    // $projectDir/bin to PATH and bind-mounts it into the container, so this
    // works under docker, singularity and conda alike.
    """
    mkdir -p copykat_out
    run_copykat.R \\
        --h5ad ${h5ad} \\
        --id_type ${id_type} \\
        --cell_line ${cell_line} \\
        --ngene_chr ${ngene_chr} \\
        --low_dr ${low_dr} \\
        --up_dr ${up_dr} \\
        --win_size ${win_size} \\
        --distance ${distance} \\
        --ks_cut ${ks_cut} \\
        --genome ${genome} \\
        --threads ${task.cpus} \\
        --out_dir copykat_out \\
        --sample_name ${sample_id}
    """

    // Lets `nextflow run ... -stub-run` exercise channel wiring and fan-out
    // without pulling the image or running CopyKAT. Filenames must stay in sync
    // with the output: block above.
    stub:
    """
    mkdir -p copykat_out
    # These are the real CopyKAT filenames: annotate_h5ad.py globs for
    # *_copykat_prediction.txt and *_copykat_CNA_raw_results_gene_by_cell.txt,
    # so a stub that emits different names would pass here and break the
    # downstream step on real data.
    echo 'cell.names\tcopykat.pred' > copykat_out/${sample_id}_copykat_prediction.txt
    echo 'hgnc_symbol\tchromosome_name' > copykat_out/${sample_id}_copykat_CNA_raw_results_gene_by_cell.txt
    echo 'chrom\tchrompos\tabspos' > copykat_out/${sample_id}_copykat_CNA_results.txt
    touch copykat_out/${sample_id}_copykat_heatmap.jpeg
    touch copykat_out/${sample_id}_copykat_result.rds
    """
}
