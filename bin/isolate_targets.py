import os
import re
import pandas as pd
import sys

df = pd.read_csv(sys.argv[1], sep="\t", header=None)
TARGETS = list(df[df.columns[3]])

with open('TARGETS.txt', 'w') as f:
    for item in TARGETS:
        f.write("%s\n" % item)
