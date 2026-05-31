#!/usr/bin/env python3
import argparse
import glob
import os
import scanpy as sc
import pandas as pd
import numpy as np


def main():
    parser = argparse.ArgumentParser(description="Inject CopyKAT ploidy predictions and CIN scores into h5ad.")
    parser.add_argument("--h5ad",        required=True)
    parser.add_argument("--sample_id",   required=True)
    parser.add_argument("--copykat_dir", required=True)
    parser.add_argument("--out_h5ad",    required=True)
    args = parser.parse_args()

    adata = sc.read_h5ad(args.h5ad)
    adata.obs['sample'] = args.sample_id

    # --- Ploidy predictions ---
    pred_files = glob.glob(os.path.join(args.copykat_dir, "*_copykat_prediction.txt"))
    if pred_files:
        pred_df = pd.read_csv(pred_files[0], sep="\t")
        pred_df = pred_df.set_index("cell.names")

        common_cells = adata.obs_names.intersection(pred_df.index)
        adata.obs['copykat_prediction'] = "not.defined"
        adata.obs.loc[common_cells, 'copykat_prediction'] = pred_df.loc[common_cells, 'copykat.pred'].values
    else:
        print(f"Warning: no *_copykat_prediction.txt found in {args.copykat_dir}. Skipping ploidy annotation.")
        adata.obs['copykat_prediction'] = "not.defined"

    # --- CIN score from raw CNA matrix ---
    # CopyKAT outputs genes x cells; values are copy-number estimates relative
    # to the diploid baseline (2.0). We normalise to 1.0 and compute Mean
    # Squared Deviation, matching the cnv_diversity_index used in infercnv.
    cna_files = glob.glob(os.path.join(args.copykat_dir, "*_copykat_CNA_raw_results_gene_by_cell.txt"))
    if cna_files:
        cna_df = pd.read_csv(cna_files[0], sep="\t", index_col=0)

        # Normalise absolute copy numbers (baseline ~2) to a 1.0-centred ratio
        cna_ratio = cna_df / 2.0

        common_cells = adata.obs_names.intersection(cna_ratio.columns)
        cna_ratio    = cna_ratio[common_cells]
        cin_score    = ((cna_ratio - 1.0) ** 2).mean(axis=0)

        adata.obs['cnv_diversity_index'] = 0.0
        adata.obs.loc[common_cells, 'cnv_diversity_index'] = cin_score.values
    else:
        print(f"Warning: no *_copykat_CNA_raw_results_gene_by_cell.txt found in {args.copykat_dir}. Skipping CIN calculation.")
        adata.obs['cnv_diversity_index'] = np.nan

    adata.write_h5ad(args.out_h5ad)


if __name__ == "__main__":
    main()