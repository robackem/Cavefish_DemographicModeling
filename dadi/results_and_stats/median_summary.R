#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
    stop("Usage: Rscript median_summary.R <input_file>", call. = FALSE)
}

infile <- args[1]

# Read the tab-delimited file
dat <- read.table(infile, header = TRUE, sep = "\t", stringsAsFactors = FALSE)

# Columns to skip
skip_cols <- c("Pop.1", "Pop.2", "Model", "Data.Likelihoods", "Optimized.Likelihoods")
keep_cols <- setdiff(names(dat), skip_cols)

# Custom formatting:
# - Small numbers (<0.01, nonzero) → scientific with 2 decimals
# - Otherwise → fixed with 2 decimals
format_val <- function(x) {
    if (is.na(x)) {
        return("NA")
    }
    if (abs(x) < 0.01 & x != 0) {
        return(formatC(x, format = "e", digits = 2))
    } else {
        return(formatC(x, format = "f", digits = 2))
    }
}

# Calculate medians and format them
medians <- sapply(dat[keep_cols], function(x) format_val(median(x, na.rm = TRUE)))

# Print header
cat(paste(keep_cols, collapse = "\t"), "\n", sep = "")

# Print medians
cat(paste(medians, collapse = "\t"), "\n", sep = "")

