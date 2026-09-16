# nf-austin/copykat

A Nextflow DSL2 pipeline for copy-number variation inference from single-cell RNA-seq data using [CopyKAT](https://github.com/navinlabcode/copykat). Clusters cells, predicts ploidy (aneuploid vs. diploid), scores chromosomal instability (CIN), and concatenates all samples into a single annotated h5ad.

## Pipeline steps

1. **RUN_COPYKAT** (`run_copykat`) — Runs CopyKAT on the raw count matrix, automatically inferring diploid reference cells. Predicts aneuploid/diploid status per cell and produces a CNA matrix. Outputs are published to `results/<sample>_copykat/`.
2. **ANNOTATE_H5AD** (`annotate_h5ad`) — Injects `copykat_prediction` (aneuploid/diploid/not.defined) and `cnv_diversity_index` (Shannon diversity index over CNV states loss/neutral/gain per cell, thresholds ±0.2) into each sample's h5ad.
3. **CONCAT_H5ADS** (`concat_h5ads`) — Concatenates all annotated h5ads into a single `combined_annotated.h5ad`, deduplicating barcodes across samples.

## Requirements

- Nextflow >= 24.04.0
- Docker (local) or Singularity/Apptainer (HPC). Conda alone is not enough — see [Container images](#container-images)
- Optional: a SLURM cluster — see [HPC / SLURM](#hpc--slurm)

## Usage

### Samplesheet (recommended, and what Seqera Platform launches with)

```bash
nextflow run nf-austin/copykat \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

`samplesheet.csv` has two columns:

```csv
sample,h5ad
tumor01,/data/tumor01/tumor01.h5ad
tumor02,/data/tumor02/tumor02.h5ad
```

`sample` becomes the output subdirectory name and must be unique. Relative `h5ad` paths are
resolved against the samplesheet's own directory first, then the launch directory — but prefer
absolute paths, especially on Seqera Platform, where the launch directory is the work directory.

### Ad-hoc glob

```bash
nextflow run nf-austin/copykat \
    -profile docker \
    --h5ad_dir "data/*.h5ad"
```

The sample id is taken from each filename with any trailing `_annotated` stripped. Mutually
exclusive with `--input`.

```bash
# Ensembl gene IDs instead of symbols
nextflow run nf-austin/copykat -profile docker --input samplesheet.csv --id_type E

# Cell-line data (no diploid baseline population to find)
nextflow run nf-austin/copykat -profile docker --input samplesheet.csv --cell_line yes

# Mouse
nextflow run nf-austin/copykat -profile docker --input samplesheet.csv --genome mm10
```

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `--input` | *(one of these two)* | Samplesheet CSV with `sample` and `h5ad` columns. |
| `--h5ad_dir` | *(one of these two)* | Glob pattern for input h5ad files, e.g. `data/*.h5ad`. |
| `--outdir` | `results` | Output directory. |
| `--id_type` | `S` | Gene ID type passed to CopyKAT: `S` for gene symbols, `E` for Ensembl IDs. Must match your `var_names`. |
| `--cell_line` | `no` | Set to `yes` for cell-line data (disables normal-cell inference). |
| `--ngene_chr` | `5` | Minimum number of genes per chromosome required by CopyKAT. |
| `--low_dr` | `0.05` | Lower bound of the dynamic range for CopyKAT smoothing. |
| `--up_dr` | `0.1` | Upper bound of the dynamic range for CopyKAT smoothing. |
| `--win_size` | `25` | Minimum window size for CopyKAT segmentation. |
| `--distance` | `euclidean` | Distance metric used for CopyKAT hierarchical clustering. |
| `--ks_cut` | `0.1` | KS-test significance cutoff for ploidy prediction. |
| `--genome` | `hg20` | Genome assembly used by CopyKAT for gene positions: `hg20` (hg38), `hg19`, or `mm10`. |
| `--copykat_container` | `ghcr.io/nf-austin/copykat:1.0.0` | R/Bioconductor image carrying CopyKAT, used by `RUN_COPYKAT`. |
| `--copykat_py_container` | `ghcr.io/nf-austin/copykat:1.0.0-py` | Python/scanpy image used by the two annotation steps. |
| `--max_memory` | `128.GB` | Memory cap applied to all processes. |
| `--max_cpus` | `32` | CPU cap applied to all processes. |
| `--max_time` | `72.h` | Runtime cap applied to all processes. |
| `--slurm_queue` | *(cluster default)* | SLURM partition (`sbatch --partition`). Used by `-profile slurm`. |
| `--slurm_account` | *(none)* | SLURM account to charge (`sbatch --account`). |
| `--cluster_options` | *(none)* | Raw sbatch options added to every job, e.g. `--qos=long`. |
| `--singularity_cache_dir` | `$NXF_SINGULARITY_CACHEDIR` | Shared directory for pulled images. Put it on storage the compute nodes can read. |
| `--conda_cache_dir` | `$NXF_CONDA_CACHEDIR` | Shared directory for conda environments. |
| `--singularity_bind` | *(none)* | Extra bind mounts, comma-separated, e.g. `/mnt/gpfs,/scratch`. |

## Output structure

```text
results/
├── <sample>_copykat/             # Per-sample CopyKAT outputs
│   └── copykat_out/
│       ├── <sample>_copykat_prediction.txt
│       ├── <sample>_copykat_CNA_raw_results_gene_by_cell.txt
│       ├── <sample>_copykat_CNA_results.txt
│       ├── <sample>_copykat_heatmap.jpeg
│       └── <sample>_copykat_result.rds
├── combined_annotated.h5ad       # All samples merged; obs columns added:
│                                 #   sample, copykat_prediction,
│                                 #   cnv_diversity_index
└── pipeline_info/                # Nextflow execution report, timeline,
                                  #   trace and DAG
```

## Seqera Platform (Nextflow Tower)

The repo ships everything Platform needs:

- **`nextflow_schema.json`** — renders the launch form. `--input` appears as a file picker wired to
  Data Explorer, CopyKAT options are grouped and documented, and tuning knobs are marked hidden so
  the default form stays short.
- **`assets/schema_input.json`** — the samplesheet contract (`sample`, `h5ad`), so a malformed sheet
  is caught before compute is provisioned.
- **`tower.yml`** — puts the per-sample predictions, CNA matrices, heatmaps and the Nextflow
  execution report in the run's **Reports** tab.

To add it: **Pipelines → Add pipeline**, point at this repository, and pick a compute environment.

Use **absolute paths** for `--input`, the h5ads it references, and `--outdir`. On a SLURM compute
environment those are ordinary shared-filesystem paths (`/mnt/gpfs/project/...`); on a cloud compute
environment they are bucket URIs (`s3://...`).

Samplesheet problems — a missing column, a duplicate sample id, an empty or unreadable `h5ad` — are
raised at launch, before Platform provisions any compute.

## HPC / SLURM

The `slurm` profile sets only the executor and queue, so it composes with an engine profile in
either order:

```bash
nextflow run nf-austin/copykat \
    -profile slurm,singularity \
    --slurm_queue normal \
    --input /mnt/gpfs/project/sheet.csv \
    --outdir /mnt/gpfs/project/results \
    --singularity_cache_dir /mnt/gpfs/shared/singularity
```

Points that matter on a cluster:

- **Use absolute paths** for `--input`, the h5ads it lists, and `--outdir`. The data is expected to
  live on the shared filesystem; nothing here assumes object storage.
- **Put `--singularity_cache_dir` on shared storage.** `$HOME` is usually quota-limited and is not
  always mounted on compute nodes. `NXF_SINGULARITY_CACHEDIR` is honored if you would rather set it
  site-wide.
- **`--singularity_bind` is the escape hatch for symlinked filesystems.** `autoMounts` binds only
  the paths Nextflow resolved itself; if `/data` is a symlink to `/mnt/gpfs/...`, the container sees
  a dangling link and reports a missing file even though the host path is fine. Bind the real
  parent: `--singularity_bind /mnt/gpfs`.
- **No image build step, and no `--fakeroot`.** Earlier versions of this pipeline built a Singularity
  image on the fly with `singularity build --fakeroot`, which most clusters forbid and which wrote
  outside the task work directory. Images are now pulled from GHCR like any other container.
- **Seqera Platform already sets the executor** when you launch against a SLURM compute
  environment, so `-profile slurm` is mainly for launching by hand from a login node.

## Container images

Built from the two Dockerfiles in this repo and published to GHCR by `.github/workflows/docker.yml`:

| Tag | Built from | Platforms | Used by |
| --- | --- | --- | --- |
| `ghcr.io/nf-austin/copykat:<ver>` | `modules/run_copykat/Dockerfile` | amd64 | `RUN_COPYKAT` |
| `ghcr.io/nf-austin/copykat:<ver>-py` | `modules/annotate_h5ad/Dockerfile` | amd64, arm64 | `ANNOTATE_H5AD`, `CONCAT_H5ADS` |

CopyKAT is not packaged on conda-forge or Bioconda — it installs from GitHub — which is why the R
image exists. Two images rather than one because the R/Bioconductor and scanpy stacks do not share a
base. The GHCR packages must be **public** for `nextflow run` to pull them without credentials.

**`-profile conda` is only a partial fallback here.** `ANNOTATE_H5AD` and `CONCAT_H5ADS` resolve
through their `environment.yml`, but `RUN_COPYKAT` cannot: CopyKAT is installed from GitHub and is
not packaged on conda-forge or Bioconda, so that process declares a `container` and no `conda`
directive. Use `-profile docker` or `-profile singularity` for a full run.

To test a change to an image before it is published:

```bash
docker build -t copykat-nf:test modules/run_copykat
nextflow run . -profile docker --input samplesheet.csv --copykat_container copykat-nf:test
```

## Notes

- `nextflow run . -stub-run --input samplesheet.csv` exercises the real channel wiring, fan-out and
  publishing with no containers and no data — useful for checking a change on a laptop.
- `nextflow lint main.nf nextflow.config modules/*/main.nf` catches config errors that `-preview`
  accepts.
