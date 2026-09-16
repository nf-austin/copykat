# Python/scanpy stack for ANNOTATE_H5AD and CONCAT_H5ADS.
#
# Separate from modules/run_copykat/Dockerfile because CopyKAT needs an
# R/Bioconductor base and these steps need scanpy; the two do not share a base
# and combining them would roughly double an already large image.
#
# Keep the pins in step with modules/annotate_h5ad/environment.yml and
# modules/concat_h5ads/environment.yml, which are the conda fallback for the
# same two processes.
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        'scanpy>=1.11' \
        'anndata>=0.11' \
        pandas \
        numpy

# Fail the build rather than a run if an import is broken.
RUN python3 -c 'import scanpy, anndata, pandas, numpy; print("scanpy", scanpy.__version__); print("anndata", anndata.__version__); print("All packages OK")'
