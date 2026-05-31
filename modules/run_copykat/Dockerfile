FROM bioconductor/bioconductor_docker:RELEASE_3_23-R-4.6.0

RUN pip3 install --no-cache-dir --break-system-packages anndata

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