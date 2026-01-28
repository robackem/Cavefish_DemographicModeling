#!/usr/bin/env python3

import os
import sys
import re
from collections import defaultdict

USAGE = "Usage: python Collate_AIC.py <POP1-POP2 or POP1_POP2>"

# Check that population pair name was provided
if len(sys.argv) < 2:
    print(USAGE)
    sys.exit(1)

popcomp_arg = sys.argv[1]

# Base output dir
base_dir = "/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/OUTPUT"

# Try common directory name variants: as-given, hyphen, underscore
candidates = [
    os.path.join(base_dir, popcomp_arg),
    os.path.join(base_dir, popcomp_arg.replace("_", "-")),
    os.path.join(base_dir, popcomp_arg.replace("-", "_")),
]

full_path = next((p for p in candidates if os.path.isdir(p)), None)
if full_path is None:
    print(f"Directory not found. Tried:\n  " + "\n  ".join(candidates))
    sys.exit(1)

# Prepare storage for replicate => model => AIC
data = defaultdict(dict)
models_set = set()

# New filename format inside the directory:
#   Pop1_Pop2_rep<digits>_<MODEL>.txt
# e.g., Choy_CMcave_rep20_AM.txt
# Capture groups: rep, model
fname_re = re.compile(r"^[A-Za-z0-9]+_[A-Za-z0-9]+_rep(\d+)_([A-Za-z0-9]+)\.txt$")

# Read AICs from each output file
for filename in sorted(os.listdir(full_path)):
    if not filename.endswith(".txt"):
        continue
    m = fname_re.match(filename)
    if not m:
        # Skip non-matching .txt files (e.g., summaries or other outputs)
        continue

    rep, model = m.groups()
    rep_id = f"rep{rep}"
    models_set.add(model)

    filepath = os.path.join(full_path, filename)
    with open(filepath, "r") as f:
        for line in f:
            # Lines look like: "#AIC: 809484.0297416621"
            if line.startswith("#AIC:"):
                parts = line.strip().split()
                # Expect ["#AIC:", "<number>", ...] (sometimes multiple AICs);
                # we take the first numeric after "#AIC:"
                try:
                    aic = float(parts[1])
                    data[rep_id][model] = aic
                except (IndexError, ValueError):
                    data[rep_id][model] = "NA"
                break  # done with this file

# Print header
models = sorted(models_set)
print("Replicate\t" + "\t".join(models))

# Print rows for each replicate (numeric sort on rep number)
for rep_id in sorted(data.keys(), key=lambda x: int(x.replace("rep", ""))):
    row = [rep_id]
    for model in models:
        row.append(str(data[rep_id].get(model, "NA")))
    print("\t".join(row))

