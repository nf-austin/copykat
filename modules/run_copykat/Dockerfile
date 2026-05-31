FROM bioconductor/bioconductor_docker:RELEASE_3_23-R-4.6.0

RUN python3 -m venv /opt/r-venv && \
    /opt/r-venv/bin/pip install --no-cache-dir anndata

ENV RETICULATE_PYTHON=/opt/r-venv/bin/python3

RUN Rscript -e 'install.packages(c("optparse", "remotes"), repos="https://cran.r-project.org")'

RUN Rscript -e 'remotes::install_github("navinlabcode/copykat")'

RUN Rscript -e ' \
    library(reticulate); \
    library(optparse); \
    library(Matrix); \
    library(copykat); \
    anndata <- import("anndata"); \
    cat("anndata version:", anndata$`__version__`, "\n"); \
    cat("All packages OK\n")'