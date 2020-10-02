###########################
# Analysis of repeat expansion results
# using STRique
###########################
library(stringr)
library(ggplot2)


# Cutoff for repeats to count (a separate histrogram without this cutoff will be made as well)
cutoff = 10
# The strique output file. Specifiy the path to this file here
strique_output = "strique.tsv" 

###
# With cutoff
###
strique <- read.table(strique_output, sep="\t", header=T)
strique <- strique[order(strique$count, decreasing = T),]
# remove small expansions
strique <- strique[strique$count > cutoff,]
df <- data.frame(expansion = strique$count, strand = strique$strand)
p <- ggplot(df, aes(x=expansion, color=strand, fill=strand)) +
  geom_histogram(alpha=0.5, bins=50)
p
ggsave(filename = "histogram_STRique_hg38.png")

# no cutoff
strique <- read.table(strique_output, sep="\t", header=T)
strique <- strique[order(strique$count, decreasing = T),]
df <- data.frame(expansion = strique$count, strand = strique$strand)
p <- ggplot(df, aes(x=expansion, color=strand, fill=strand)) +
  geom_histogram(alpha=0.5, bins=50)
p
ggsave(filename = "histogram_STRique_hg38_noCutoff.png")


#=======================#
