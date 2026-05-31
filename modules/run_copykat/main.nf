process RUN_COPYKAT {
    tag { sample_id }
    publishDir { "${params.outdir}/${sample_id}_copykat" }, mode: 'copy'

    conda "${moduleDir}/environment.yml"

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
    """
    mkdir -p copykat_out
    Rscript ${moduleDir}/run_copykat.R \\
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
}