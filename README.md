# nf-austin/copykat

A Nextflow DSL2 pipeline for copy-number variation inference from single-cell RNA-seq data using [CopyKAT](https://github.com/navinlabcode/copykat). Clusters cells, predicts ploidy (aneuploid vs. diploid), scores chromosomal instability (CIN), and concatenates all samples into a single annotated h5ad.

## Pipeline steps

1. **RUN_COPYKAT** (`copykat`) — Runs CopyKAT on the raw count matrix, automatically inferring diploid reference cells. Predicts aneuploid/diploid status per cell and produces a CNA matrix. Outputs are published to `results/<sample>_copykat/`.
2. **ANNOTATE_H5AD** (`scanpy`, `pandas`) — Injects `copykat_prediction` (aneuploid/diploid/not.defined) and `cnv_diversity_index` (mean squared deviation from diploid baseline, a CIN proxy) into each sample's h5ad.
3. **CONCAT_H5ADS** (`anndata`) — Concatenates all annotated h5ads into a single `combined_annotated.h5ad`, deduplicating barcodes across samples.

## Requirements

- Nextflow >= 24.04.0
- Docker, Singularity, or Conda

## Usage

```bash
nextflow run nf-austin/copykat \
    -profile conda \
    --h5ad_dir "data/*.h5ad"
```

Override any parameter on the command line:

```bash
nextflow run nf-austin/copykat \
    -profile conda \
    --h5ad_dir "data/*.h5ad" \
    --id_type E \
    --resolution 0.5 \
    --outdir my_results
```

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `--h5ad_dir` | `data/*.h5ad` | Glob pattern for input h5ad files. |
| `--outdir` | `results` | Output directory. |
| `--id_type` | `S` | Gene ID type passed to CopyKAT: `S` for gene symbols, `E` for Ensembl IDs. |
| `--cell_line` | `no` | Set to `yes` for cell-line data (disables normal-cell inference). |
| `--ngene_chr` | `5` | Minimum number of genes per chromosome required by CopyKAT. |
| `--low_dr` | `0.05` | Lower bound of the dynamic range for CopyKAT smoothing. |
| `--up_dr` | `0.1` | Upper bound of the dynamic range for CopyKAT smoothing. |
| `--win_size` | `25` | Minimum window size for CopyKAT segmentation. |
| `--distance` | `euclidean` | Distance metric used for CopyKAT hierarchical clustering. |
| `--ks_cut` | `0.1` | KS-test significance cutoff for ploidy prediction. |
| `--genome` | `hg20` | Genome assembly used by CopyKAT for gene positions: `hg20` (hg38), `hg19`, or `mm10`. |
| `--max_memory` | `128.GB` | Memory cap applied to all processes. |
| `--max_cpus` | `32` | CPU cap applied to all processes. |
| `--max_time` | `72.h` | Runtime cap applied to all processes. |

## Output structure

```text
results/
├── <sample>_copykat/             # Per-sample CopyKAT outputs
│   ├── <sample>_copykat_prediction.txt
│   ├── <sample>_copykat_CNA_raw_results_gene_by_cell.txt
│   ├── <sample>_copykat_heatmap.jpeg
│   ├── <sample>_copykat_CNA_results.obj.RData
│   └── <sample>_copykat_result.rds
└── combined_annotated.h5ad       # All samples merged; obs columns added:
                                  #   sample, copykat_prediction,
                                  #   cnv_diversity_index
```