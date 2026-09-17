process ANNOTATE_H5AD {
    tag { sample_id }

    conda "${moduleDir}/environment.yml"
    container params.copykat_py_container

    input:
    tuple val(sample_id), path(h5ad), path(copykat_dir)

    output:
    tuple val(sample_id), path("${sample_id}_annotated.h5ad"), emit: h5ad

    script:
    // Scripts live in bin/ and are called bare: Nextflow prepends
    // $projectDir/bin to PATH and bind-mounts it into the container, so this
    // works under docker, singularity and conda alike.
    """
    annotate_h5ad.py \\
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
