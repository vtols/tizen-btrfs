#!/usr/bin/python3

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

from collections import defaultdict
from pathlib import Path

def plot_stats(name, y):
    stats = [mean, median, variance] = \
        [np.mean(y), np.median(y), np.var(y)]

    for stat_file, stat in zip(stat_files, stats):
        with stat_file.open('a') as f:
            f.write("{} {}\n".format(name, stat))

    x = list(range(len(y)))
    y_mean = [mean for i in x]
    y_median = [median for i in x]
    fig, ax = plt.subplots()
    data_line = ax.plot(x, y, 'o', label='Time', alpha=0.2)
    mean_line, = ax.plot(x, y_mean, label='Mean time',
                    linestyle='-', color='red', linewidth=2)
    median_line, = ax.plot(x, y_median, label='Median time',
                    linestyle='-', color='orange', linewidth=2)
    plt.legend([mean_line, median_line], ['Mean', 'Median'])
    plt.xlim([min(x), max(x)])
    plt.title(name)
    file_t = str(data_dir / (name + '.{}'))
    plt.savefig(file_t.format('png'))
    plt.savefig(file_t.format('svg'))
    #plt.show()

def plot_density(name, y):
    plt.figure()
    plt.hist(y, bins='auto')
    plt.title(name + " (histogram)")
    plt.savefig(str(data_dir / (name + '.hist.png')))

def entries(name):
    lines = (run_dir / name).open().readlines()
    return list(map(str.split, lines))

def entry_map(name):
    return { k: v for [k, v] in entries(name) }

data_dir = Path.cwd() / sys.argv[1]
medians = data_dir / 'medians.txt'
means = data_dir / 'means.txt'
variances = data_dir / 'variances.txt'
stat_files = [means, medians, variances]

system_start_time = []
apps_start_time = defaultdict(lambda: [])

samples = 0

for stat_file in stat_files:
    if stat_file.exists():
        os.remove(str(stat_file))

for run_dir in data_dir.iterdir():

    if run_dir.is_dir():
        #print("Reading", run_dir)
        try:
            pids = entry_map('pids.txt')
            starts = entry_map('dlog.txt')
            for name, pid in pids.items():
                app_time = int(starts[pid]) / 1000
                apps_start_time[name].append(app_time)

            system_time = float(entries('startup.txt')[0][2])
            system_start_time.append(system_time)
            samples += 1
        except:
            print("Bad data in", run_dir)

print("Total {} samples".format(samples))

plot_stats('sys', system_start_time)
for name, data in apps_start_time.items():
    print("Plotting data for", name)
    plot_stats(name, data)
    plot_density(name, data)
