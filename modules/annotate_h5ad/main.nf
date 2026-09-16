process ANNOTATE_H5AD {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"
    container params.copykat_py_container

    input:
    // Staged as a path input, not referenced via ${moduleDir}, which is not
    // bind-mounted into the container.
    tuple val(sample_id), path(h5ad), path(copykat_dir)
    path run_script

    output:
    tuple val(sample_id), path("${sample_id}_annotated.h5ad"), emit: h5ad

    script:
    """
    python3 ${run_script} \\
        --h5ad ${h5ad} \\
        --sample_id ${sample_id} \\
        --copykat_dir ${copykat_dir} \\
        --out_h5ad ${sample_id}_annotated.h5ad
    """

    stub:
    """
    touch ${sample_id}_annotated.h5ad
    """
}
