#!/usr/bin/env python3

import os
import re
from collections import defaultdict, OrderedDict

# Directories
output_root = "/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Scripts/OUTPUT"
results_dir = "/home/mcgaughs/robac028/CabMoro_PopGen/dadi_package/Results"

# Ensure results directory exists
os.makedirs(results_dir, exist_ok=True)

# Store parsed data by model
model_data = defaultdict(list)
model_fields = defaultdict(set)

# Pattern to extract replicate number
rep_pattern = re.compile(r"rep(\d+)")

# Walk through each population pair directory
for popdir in sorted(os.listdir(output_root)):
    subdir = os.path.join(output_root, popdir)
    if not os.path.isdir(subdir):
        continue

    for filename in sorted(os.listdir(subdir)):
        if not filename.endswith(".txt"):
            continue

        filepath = os.path.join(subdir, filename)
        entry = {}
        replicate_match = rep_pattern.search(filename)
        entry["replicate"] = replicate_match.group(1) if replicate_match else "NA"

        model = None

        with open(filepath, "r") as f:
            for line in f:
                if line.startswith("#") and not line.startswith("#LocusLem"):
                    parts = line[1:].strip().split(":", 1)
                    if len(parts) == 2:
                        key = parts[0].strip()
                        val = parts[1].strip()
                        entry[key] = val
                        if key == "Model":
                            model = val

        if model:
            model_data[model].append(entry)
            model_fields[model].update(entry.keys())

# Write summary files per model
for model, entries in model_data.items():
    fields = ["replicate"] + sorted([f for f in model_fields[model] if f != "replicate"])
    output_file = os.path.join(results_dir, f"{model}_summary.txt")

    with open(output_file, "w") as out:
        out.write("\t".join(fields) + "\n")
        for entry in entries:
            row = [entry.get(field, "NA") for field in fields]
            out.write("\t".join(row) + "\n")
