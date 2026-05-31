FROM bioconductor/bioconductor_docker:RELEASE_3_23-R-4.6.0

RUN Rscript -e 'install.packages(c("optparse", "remotes"), repos="https://cran.r-project.org")'

RUN Rscript -e ' \
    BiocManager::install("zellkonverter", ask=FALSE); \
    if (!requireNamespace("zellkonverter", quietly=TRUE)) stop("zellkonverter install failed")'

RUN Rscript -e 'remotes::install_github("navinlabcode/copykat")'

ENV BASILISK_USE_SYSTEM_DIR=1

RUN Rscript -e ' \
    library(basilisk); \
    library(zellkonverter); \
    proc <- basilisk::basiliskStart(zellkonverterAnnDataEnv()); \
    basilisk::basiliskStop(proc); \
    cat("basilisk environment ready\n")'

RUN Rscript -e ' \
    library(optparse); \
    library(Matrix); \
    library(SummarizedExperiment); \
    library(zellkonverter); \
    library(copykat); \
    cat("All packages OK\n")'