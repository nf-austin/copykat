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
    # CopyKAT outputs a genes x cells log-ratio matrix centred at 0 (diploid).
    # We compute Shannon diversity over three CNV states (loss/neutral/gain, ±0.2)
    # per cell as the cnv_diversity_index.
    cna_files = glob.glob(os.path.join(args.copykat_dir, "*_copykat_CNA_raw_results_gene_by_cell.txt"))
    if cna_files:
        cna_df = pd.read_csv(cna_files[0], sep="\t", index_col=0)

        # Select only cell-barcode columns; metadata cols (chromosome_name, etc.) are excluded.
        common_cells = adata.obs_names.intersection(cna_df.columns)
        if len(common_cells) == 0:
            print(f"Warning: no cell barcodes overlap between h5ad and CNA matrix. "
                  f"h5ad example: {list(adata.obs_names[:3])}, "
                  f"CNA example: {list(cna_df.columns[:3])}")

        cna_cells = cna_df[common_cells].apply(pd.to_numeric, errors="coerce")

        # Shannon diversity index over CNV states (loss / neutral / gain) per cell.
        # Values are log-ratio deviations centred at 0; thresholds ±0.2 define states.
        def _shannon_diversity(col):
            vals = col.dropna().values
            if len(vals) == 0:
                return np.nan
            loss    = (vals < -0.2).sum()
            neutral = ((vals >= -0.2) & (vals <= 0.2)).sum()
            gain    = (vals > 0.2).sum()
            counts  = np.array([loss, neutral, gain], dtype=float)
            p = counts[counts > 0] / counts.sum()
            return float(-(p * np.log2(p)).sum())

        cin_score = cna_cells.apply(_shannon_diversity, axis=0)

        cin_series = pd.Series(np.nan, index=adata.obs_names, dtype=float)
        cin_series[common_cells] = cin_score.values
        adata.obs['cnv_diversity_index'] = cin_series
    else:
        print(f"Warning: no *_copykat_CNA_raw_results_gene_by_cell.txt found in {args.copykat_dir}. Skipping CIN calculation.")
        adata.obs['cnv_diversity_index'] = np.nan

    adata.write_h5ad(args.out_h5ad)


if __name__ == "__main__":
    main()