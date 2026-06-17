#### DAPC for Ixodes scapularis dataset (MAF 0.1, miss 0.05) ####
#################################################################
#### Interactive Start with all specimens dataset (K chosen manually) ####

# Load packages
library("adegenet")

# Set working directory
setwd("/work/fauverlab/zachpella/scatter_20/downsampled_our_data_and_online/final_vcf")

# ----------------------------------------------------------------------------------
# READ IN DATA
# ----------------------------------------------------------------------------------
cat("Reading structure file...\n")
data <- read.structure("combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi_pruned_noheader.str",
                       n.ind = 200,
                       n.loc = 20914,
                       onerowperind = FALSE,
                       col.lab = 1,
                       col.pop = 0,
                       row.marknames = 0,
                       NA.char = "-9",
                       ask = FALSE)
cat("Data loaded successfully\n")

# ----------------------------------------------------------------------------------
# STEP 1: Find clusters - Save BIC plot
# ----------------------------------------------------------------------------------
cat("Running find.clusters...\n")

pdf("step1_BIC_plot_ixodes.pdf", width = 10, height = 8)
grp <- find.clusters(data,
                     max.n.clust = 192,
                     stat = c("BIC"))
dev.off()
cat("BIC plot saved to step1_BIC_plot_ixodes.pdf\n")

grp$n.clust <- length(unique(grp$grp))
cat("Cluster count (K) set to:", grp$n.clust, "\n")

# ----------------------------------------------------------------------------------
# STEP 2: Preliminary DAPC
# ----------------------------------------------------------------------------------
cat("Running preliminary DAPC...\n")
pdf("step2_prelim_dapc_ixodes.pdf", width = 10, height = 8)
dapc.prelim <- dapc(data, grp$grp)
dev.off()
cat("Preliminary DAPC plot saved to step2_prelim_dapc_ixodes.pdf\n")

cat("Generating PCA scatter plot from preliminary DAPC...\n")
pdf("step2_PCA_scatter_ixodes.pdf", width = 10, height = 8)
scatter(dapc.prelim,
        scree.da = FALSE,
        bg = "white",
        pch = 20,
        cell = 0,
        cstar = 0,
        solid = 0.4,
        cex = 3,
        clab = 0,
        leg = TRUE,
        txt.leg = paste("Cluster", 1:grp$n.clust))
dev.off()
cat("PCA scatter plot saved to step2_PCA_scatter_ixodes.pdf\n")

# ----------------------------------------------------------------------------------
# STEP 3: Optimize a-score
# ----------------------------------------------------------------------------------
cat("Optimizing a-score...\n")
pdf("step3_a_score_optimization_ixodes.pdf", width = 10, height = 8)
temp <- optim.a.score(dapc.prelim)
dev.off()
cat("A-score optimization plot saved to step3_a_score_optimization_ixodes.pdf\n")

# ----------------------------------------------------------------------------------
# STEP 4: Final DAPC
# ----------------------------------------------------------------------------------
cat("Running final DAPC...\n")
pdf("step4_final_dapc_ixodes.pdf", width = 10, height = 8)
dapc <- dapc(data, grp$grp)
dev.off()
cat("Final DAPC plot saved to step4_final_dapc_ixodes.pdf\n")

remove(dapc.prelim)
gc()

# ----------------------------------------------------------------------------------
# STEP 5: Save results and final scatter plot (no labels)
# ----------------------------------------------------------------------------------
cat("Saving clustering results...\n")
clustering.key <- round(dapc$posterior, 3)
write.table(clustering.key,
            file = "clustering_key_ixodes_scapularis.DAPC.tsv",
            sep = "\t",
            row.names = TRUE,
            col.names = TRUE,
            quote = FALSE)

custom_colors <- c("#AD122A","#D4A017", "#129DBF")

cat("Generating final scatter plot...\n")
pdf("step5_DAPC_scatter_plot_ixodes.pdf", width = 10, height = 8)
scatter(dapc,
        scree.da = FALSE,
        bg = "white",
        pch = 20,
        cell = 0,
        cstar = 0,
        solid = 0.4,
        cex = 3,
        clab = 0,
        leg = TRUE,
        txt.leg = paste("Cluster", 1:grp$n.clust),
        col = custom_colors[1:grp$n.clust])
dev.off()
cat("Final scatter plot saved to step5_DAPC_scatter_plot_ixodes.pdf\n")

# ----------------------------------------------------------------------------------
# STEP 5b: Final scatter plot with admixed individual labels
# ----------------------------------------------------------------------------------
cat("Generating labeled scatter plot for admixed individuals...\n")

admix_threshold <- 0.90

ind_scores <- dapc$ind.coord[, 1]
posteriors <- dapc$posterior

admixed_idx <- which(apply(posteriors, 1, max) < admix_threshold)
admixed_names <- rownames(posteriors)[admixed_idx]
admixed_scores <- ind_scores[admixed_idx]

cat("Admixed individuals (posterior < 0.80):\n")
print(admixed_names)

pdf("step5b_DAPC_scatter_labeled_admixed.pdf", width = 12, height = 8)
scatter(dapc,
        scree.da = FALSE,
        bg = "white",
        pch = 20,
        cell = 0,
        cstar = 0,
        solid = 0.4,
        cex = 3,
        clab = 0,
        leg = TRUE,
        txt.leg = paste("Cluster", 1:grp$n.clust),
        col = custom_colors[1:grp$n.clust])

text(x = admixed_scores,
     y = rep(-0.03, length(admixed_scores)),
     labels = admixed_names,
     srt = 90,
     adj = 1,
     cex = 0.5,
     xpd = TRUE)
dev.off()
cat("Labeled plot saved to step5b_DAPC_scatter_labeled_admixed.pdf\n")

cat("\n===========================================\n")
cat("Analysis complete! Files saved:\n")
cat("  - step1_BIC_plot_ixodes.pdf\n")
cat("  - step2_prelim_dapc_ixodes.pdf\n")
cat("  - step2_PCA_scatter_ixodes.pdf\n")
cat("  - step3_a_score_optimization_ixodes.pdf\n")
cat("  - step4_final_dapc_ixodes.pdf\n")
cat("  - step5_DAPC_scatter_plot_ixodes.pdf\n")
cat("  - step5b_DAPC_scatter_labeled_admixed.pdf\n")
cat("  - clustering_key_ixodes_scapularis.DAPC.tsv\n")
cat("===========================================\n")
