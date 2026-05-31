#!/usr/bin/env Rscript
library(optparse)
library(copykat)
library(reticulate)
library(Matrix)

option_list <- list(
    make_option(c("--h5ad"),        type="character", default=NULL,        help="Input H5AD file"),
    make_option(c("--id_type"),     type="character", default="S",         help="Gene ID type: S (symbol) or E (Ensembl)"),
    make_option(c("--cell_line"),   type="character", default="no",        help="Cell line mode: yes or no"),
    make_option(c("--ngene_chr"),   type="integer",   default=5L,          help="Minimum genes per chromosome"),
    make_option(c("--low_dr"),      type="double",    default=0.05,        help="Lower bound of dynamic range"),
    make_option(c("--up_dr"),       type="double",    default=0.1,         help="Upper bound of dynamic range"),
    make_option(c("--win_size"),    type="integer",   default=25L,         help="Minimum window size for segmentation"),
    make_option(c("--distance"),    type="character", default="euclidean", help="Distance method for clustering"),
    make_option(c("--ks_cut"),      type="double",    default=0.1,         help="KS statistics cutoff for ploidy prediction"),
    make_option(c("--genome"),      type="character", default="hg20",      help="Genome assembly: hg20 (hg38), hg19, or mm10"),
    make_option(c("--threads"),     type="integer",   default=4L,          help="Number of cores"),
    make_option(c("--out_dir"),     type="character", default="copykat_out", help="Output directory"),
    make_option(c("--sample_name"), type="character", default="sample",    help="Sample name prefix for output files")
)

opt_parser <- OptionParser(option_list=option_list)
opt        <- parse_args(opt_parser)

if (is.null(opt$h5ad)) {
    print_help(opt_parser)
    stop("Missing required arguments.", call.=FALSE)
}

# Read H5AD via Python anndata — avoids zellkonverter's basilisk/conda management.
# AnnData stores X as (cells × genes); copykat expects (genes × cells).
anndata    <- import("anndata")
ad         <- anndata$read_h5ad(opt$h5ad)
x          <- ad$X
if (py_has_attr(x, "toarray")) x <- x$toarray()   # handle sparse storage
expression <- t(as.matrix(x))
rownames(expression) <- as.character(ad$var_names$to_list())
colnames(expression) <- as.character(ad$obs_names$to_list())

# CopyKAT writes all output files to the working directory using sam.name as
# a prefix, so change into out_dir before running.
old_wd <- getwd()
setwd(opt$out_dir)

copykat_result <- copykat(
    rawmat          = expression,
    id.type         = opt$id_type,
    cell.line       = opt$cell_line,
    ngene.chr       = opt$ngene_chr,
    LOW.DR          = opt$low_dr,
    UP.DR           = opt$up_dr,
    win.size        = opt$win_size,
    distance        = opt$distance,
    KS.cut          = opt$ks_cut,
    sam.name        = opt$sample_name,
    genome          = opt$genome,
    n.cores         = opt$threads
)

setwd(old_wd)

saveRDS(copykat_result, file.path(opt$out_dir, paste0(opt$sample_name, "_copykat_result.rds")))
