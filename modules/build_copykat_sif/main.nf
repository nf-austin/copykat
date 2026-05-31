process BUILD_COPYKAT_SIF {
    output:
    val true, emit: ready

    script:
    def def_file = "${projectDir}/modules/run_copykat/copykat.def"
    """
    singularity build --fakeroot "${params.copykat_sif}" "${def_file}"
    """
}