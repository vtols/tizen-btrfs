#!/usr/bin/python3

import os
import sys
import math
import numpy as np
import matplotlib.pyplot as plt

from collections import defaultdict
from pathlib import Path

# File with startup directories names
# Format:
# <directory> <displayed name (on graphs)>
startups_file = sys.argv[1]
startups = []
labels = []
colors = 'rgby'
plots = Path.cwd() / 'startups'
medians_dict = defaultdict(lambda: [])

if not plots.exists():
    plots.mkdir()

with (Path.cwd() / startups_file).open() as f:
    for line in f:
        directory, label = line.split()
        startups.append(directory)
        labels.append(label)

for startup in startups:
    data_dir = Path.cwd() / startup
    medians = data_dir / 'medians.txt'
    with medians.open() as f:
        for line in f:
            name, time = line.split()
            medians_dict[name].append(float(time))

x = range(len(startups))
for k, v in medians_dict.items():
    plt.figure()
    bars = plt.bar(x, v, align='center')
    low = min(v)
    high = max(v)
    plt.ylim([low  - 0.5 * (high - low),
              high + 0.5 * (high - low)])
    for bar, color in zip(bars, colors):
        bar.set_color(color)
    plt.xticks(x, labels)
    plt.xlabel('File system')
    plt.ylabel('Start time')
    plt.title('Median start time for ' + k)
    filename = str(plots / k)
    plt.savefig(filename + '.png')
    plt.savefig(filename + '.svg')
