import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("study")
parser.add_argument("reference")
parser.add_argument("targets")
parser.add_argument("fastq")
parser.add_argument("--gstride", default=100)
parser.add_argument("--target_proximity", default=10000)
parser.add_argument("--offtarget_level", default=20)
parser.add_argument("--threads", "-t", default=8)

# parse arguments
args = parser.parse_args()
study = args.study
reference = args.reference
targets = args.targets
fastq = args.fastq
gstride = args.gstride
target_proximity = args.target_proximity
offtarget = args.offtarget_level
threads = args.threads

# Create the config file
config = f"""

pipeline: "Nanopore Cas9 Enrichment"

study_name: "{study}"

reference_genome: "{fastq}"

target_regions: "{targets}"

fastq: "{fastq}"

gstride: {gstride}

target_proximity: {target_proximity}

offtarget_level: {offtarget}

threads: {threads}

tutorialText: TRUE
"""

f = open("config.yml", "w")
f.write(config)
f.close()
