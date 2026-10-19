#!/usr/bin/env python3
"""flow/scripts/cov_merge.py -- merge the fallback functional-coverage files of a regression.

Lab V3. Block-independent. A testbench that keeps its coverage model in plain counters
writes one file per run, next to the simulation log:

    build/<ip>/<cfg>/sim/cov_<test>_s<seed>.txt      one line per planned bin: "<bin> <count>"

This script sums the files PER CONFIGURATION (<cfg> directory: a bin is closed if any run
of that configuration hit it), prints every configuration's result and its holes, and
exits with 1 if any planned bin is still 0.

Arguments (any mix):
    <regress_summary.txt>   the summary of 'make regress': exactly the runs of that
                            regression (the coverage file next to each listed log)
    <directory>             every cov_*.txt below it (e.g. build/<ip> or build/<ip>/<cfg>)
    <cov_file.txt>          single files

Examples:
    $PYTHON flow/scripts/cov_merge.py build/<ip>/regress_summary.txt
    $PYTHON flow/scripts/cov_merge.py build/<ip>/<cfg>
    $PYTHON flow/scripts/cov_merge.py -v build/<ip>            (-v: print every bin)
"""

import os
import re
import sys
from collections import OrderedDict

COV_RE = re.compile(r"^cov_.+_s\d+\.txt$")


def repo_root():
    return os.environ.get("REPO_ROOT", os.getcwd())


def files_from_summary(path):
    """Coverage files of the runs listed in a 'make regress' summary."""
    out = []
    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                continue
            for word in line.split():
                if word.endswith(".log"):
                    log = word if os.path.isabs(word) else os.path.join(repo_root(), word)
                    base = os.path.basename(log)[:-len(".log")]
                    cov = os.path.join(os.path.dirname(log), "cov_" + base + ".txt")
                    if os.path.isfile(cov):
                        out.append(cov)
    return out


def collect(args):
    files = []
    for a in args:
        if os.path.isdir(a):
            for root, _, names in os.walk(a):
                files += [os.path.join(root, n) for n in sorted(names) if COV_RE.match(n)]
        elif os.path.isfile(a) and COV_RE.match(os.path.basename(a)):
            files.append(a)
        elif os.path.isfile(a):
            files += files_from_summary(a)
        else:
            sys.exit("cov_merge: no such file or directory: %s" % a)
    return sorted(set(os.path.abspath(f) for f in files))


def config_of(path):
    """build/<ip>/<cfg>/sim/cov_x.txt -> '<ip>/<cfg>' (the directory above sim/)."""
    d = os.path.dirname(path)
    if os.path.basename(d) == "sim":
        d = os.path.dirname(d)
    return os.path.relpath(d, os.path.join(repo_root(), "build"))


def main(argv):
    verbose = "-v" in argv
    args = [a for a in argv if a != "-v"]
    if not args or "-h" in args or "--help" in args:
        print(__doc__)
        return 2
    files = collect(args)
    if not files:
        print("cov_merge: no coverage files (cov_<test>_s<seed>.txt) found")
        return 1

    merged = OrderedDict()          # config -> OrderedDict(bin -> count)
    runs = {}
    for path in files:
        cfg = config_of(path)
        bins = merged.setdefault(cfg, OrderedDict())
        runs[cfg] = runs.get(cfg, 0) + 1
        with open(path) as f:
            for line in f:
                parts = line.split()
                if len(parts) != 2:
                    continue
                bins[parts[0]] = bins.get(parts[0], 0) + int(parts[1])

    total_holes = 0
    for cfg, bins in merged.items():
        holes = [b for b, n in bins.items() if n == 0]
        total_holes += len(holes)
        hit = len(bins) - len(holes)
        print("COVERAGE %-50s %3d/%-3d bins hit (%5.1f%%), %d runs%s"
              % (cfg, hit, len(bins), 100.0 * hit / max(len(bins), 1), runs[cfg],
                 "" if holes else "  CLOSED"))
        if verbose:
            for b, n in bins.items():
                print("    %-32s %10d%s" % (b, n, "  <-- HOLE" if n == 0 else ""))
        else:
            for b in holes:
                print("    HOLE %s" % b)
    print("cov_merge: %s (%d files, %d configurations, %d holes)"
          % ("CLOSED" if total_holes == 0 else "HOLES", len(files), len(merged), total_holes))
    return 0 if total_holes == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
