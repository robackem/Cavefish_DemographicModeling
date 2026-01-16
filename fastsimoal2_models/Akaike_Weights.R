# Akaike_Weights.R

# Generate Akaike weights for each model, for each replicate. The goal of this
# is to show the variation in confidence that we have that we chose the best
# model for each population comparison. Takes the path to the collated AIC
# values as an argument

args <- commandArgs(TRUE)

# Read in the AIC table
aic_dat <- read.table(args[1], header=TRUE, sep="\t")

# Function to compute Akaike weights from a vector of AICs
akaike_weight <- function(x) {
    x <- as.numeric(x)
    min_aic <- min(x, na.rm=TRUE)
    delta_aic <- x - min_aic
    exp_aic <- exp(-0.5 * delta_aic)
    exp_aic / sum(exp_aic)
}

# Convert all columns (except the first) to numeric and apply weights row-wise
aic_matrix <- as.matrix(sapply(aic_dat[ , -1], as.numeric))
a_weights <- t(apply(aic_matrix, 1, akaike_weight))

# Average weights across replicates
a_weights.mean <- colMeans(a_weights, na.rm=TRUE)

# Add header (model names)
model_names <- colnames(aic_dat)[-1]
names(a_weights.mean) <- model_names

# Print header and values
cat(paste(c("Model", model_names), collapse="\t"), "\n")
cat(paste(c("Mean_Weight", format(a_weights.mean, digits=5)), collapse="\t"), "\n")

