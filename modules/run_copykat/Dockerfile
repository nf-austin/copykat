FROM rocker/r-ver:4.4.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libhdf5-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages( \
        c("BiocManager", "remotes", "optparse", "Matrix"), \
        repos="https://cran.r-project.org")'

RUN Rscript -e 'BiocManager::install( \
        c("zellkonverter", "SummarizedExperiment"), ask=FALSE)'

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
