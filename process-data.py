#!/usr/bin/python3

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

from collections import defaultdict
from pathlib import Path

data_dir = Path.cwd() / sys.argv[1]

system_start_time = []
apps_start_time = defaultdict(lambda: [])

for run_dir in data_dir.iterdir():
    print(run_dir)
    def entries(name):
        lines = (run_dir / name).open().readlines()
        return list(map(str.split, lines))

    def entry_map(name):
        return { k: v for [k, v] in entries(name) }

    if run_dir.is_dir():
        pids = entry_map('pids.txt')
        starts = entry_map('dlog.txt')
        for name, pid in pids.items():
            app_time = int(starts[pid]) / 1000
            apps_start_time[name].append(app_time)

        system_time = float(entries('startup.txt')[0][2])
        system_start_time.append(system_time)

def plot_medians(name, y):
    median = np.median(y)
    x = list(range(len(y)))
    x.reverse()
    y_median = [median for i in x]
    fig, ax = plt.subplots()
    data_line = ax.plot(x, y, label='Time', marker='o')
    meidan_line = ax.plot(x, y_median, label='Median time', linestyle='--')
    plt.title(name)
    plt.savefig(str(data_dir / (name + '.png')))
    #plt.show()

print(apps_start_time)
print(system_start_time)
plot_medians('sys', system_start_time)
for name, data in apps_start_time.items():
    plot_medians(name, data)