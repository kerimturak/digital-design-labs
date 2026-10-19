#!/usr/bin/env python3
"""flow/scripts/plot_sweep.py <sweep.csv>  -- plots of a 'make sweep' CSV (Lab P3).

Writes next to the CSV:
  <stem>_area.{png|svg}   bar chart: area per configuration, bars labeled with the flop count
  <stem>_fmax.{png|svg}   line chart: Fmax (MHz) per configuration
PNG with matplotlib when it is installed; otherwise a dependency-free SVG with the same
content (the Synopsys cloud's python3.11 has no matplotlib), converted to PNG with
rsvg-convert when that is available. One chart per measure:
area and Fmax have different units and are never put on a shared or dual axis.
Run as: $(PYTHON) flow/scripts/plot_sweep.py build/<ip>/sweep/<top>_sweep.csv
"""

import csv
import html
import os
import shutil
import subprocess
import sys

INK, INK2, GRID, SURFACE, SERIES = '#0b0b0b', '#52514e', '#e4e3df', '#fcfcfb', '#2a78d6'


def read(path):
    with open(path, newline='') as f:
        rows = list(csv.DictReader(f))
    if not rows:
        sys.exit(f'plot_sweep: {path}: no rows')
    return rows


def nice_max(v):
    """Round the axis maximum up to 1, 2 or 5 times a power of ten."""
    if v <= 0:
        return 1.0
    p = 10 ** len(str(int(v))) / 10
    for m in (1, 2, 5, 10):
        if m * p >= v:
            return m * p
    return 10 * p


def svg_chart(path, title, labels, values, kind, ylabel, notes):
    w, h, l, r, t, b = 720, 400, 72, 24, 48, 96
    pw, ph = w - l - r, h - t - b
    ymax = nice_max(max(values) * 1.1)
    n = len(values)
    step = pw / n
    y = lambda v: t + ph - v / ymax * ph
    e = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
         f'font-family="Helvetica, Arial, sans-serif" font-size="12">',
         f'<rect width="{w}" height="{h}" fill="{SURFACE}"/>',
         f'<text x="{l}" y="24" font-size="15" font-weight="bold" fill="{INK}">{html.escape(title)}</text>']
    for i in range(6):                                     # recessive grid + y ticks
        v = ymax * i / 5
        e.append(f'<line x1="{l}" x2="{w - r}" y1="{y(v):.1f}" y2="{y(v):.1f}" stroke="{GRID}"/>')
        e.append(f'<text x="{l - 6}" y="{y(v) + 4:.1f}" text-anchor="end" fill="{INK2}">{v:g}</text>')
    e.append(f'<text x="16" y="{t + ph / 2}" transform="rotate(-90 16 {t + ph / 2})" '
             f'text-anchor="middle" fill="{INK2}">{html.escape(ylabel)}</text>')
    pts = []
    for i, (lab, v) in enumerate(zip(labels, values)):
        cx = l + step * (i + 0.5)
        if kind == 'bar':
            bw = min(48, step * 0.6)
            e.append(f'<rect x="{cx - bw / 2:.1f}" y="{y(v):.1f}" width="{bw:.1f}" '
                     f'height="{t + ph - y(v):.1f}" rx="4" fill="{SERIES}"><title>{html.escape(lab)}: {v:g}</title></rect>')
        else:
            pts.append((cx, y(v)))
        e.append(f'<text x="{cx:.1f}" y="{y(v) - 8:.1f}" text-anchor="middle" fill="{INK}">'
                 f'{html.escape(notes[i])}</text>')
        # one PARAMS assignment per line, so long configurations do not collide
        lines = ''.join(f'<tspan x="{cx:.1f}" dy="{0 if k == 0 else 14}">{html.escape(w_)}</tspan>'
                        for k, w_ in enumerate(lab.split()))
        e.append(f'<text y="{t + ph + 18}" text-anchor="middle" fill="{INK2}">{lines}</text>')
    if pts:
        e.append(f'<polyline fill="none" stroke="{SERIES}" stroke-width="2" points="'
                 + ' '.join(f'{x:.1f},{yy:.1f}' for x, yy in pts) + '"/>')
        for (x, yy), lab, v in zip(pts, labels, values):
            e.append(f'<circle cx="{x:.1f}" cy="{yy:.1f}" r="4" fill="{SERIES}" stroke="{SURFACE}" '
                     f'stroke-width="2"><title>{html.escape(lab)}: {v:g}</title></circle>')
    e.append(f'<line x1="{l}" x2="{w - r}" y1="{t + ph}" y2="{t + ph}" stroke="{INK2}"/>')
    e.append('</svg>')
    with open(path, 'w') as f:
        f.write('\n'.join(e) + '\n')


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    rows = read(path)
    stem = os.path.splitext(path)[0]
    labels = [r['params'] for r in rows]
    area = [float(r['area']) for r in rows]
    fmax = [float(r['fmax_mhz']) for r in rows]
    lib = rows[0].get('library', '')
    a_title = f'Area per configuration ({lib}; labels: flip-flops)'
    f_title = f'Fmax per configuration ({lib})'
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        for fname, title, vals, kind, ylab, notes in (
                (stem + '_area.png', a_title, area, 'bar', 'cell area (library units)',
                 [r['flops'] + ' FF' for r in rows]),
                (stem + '_fmax.png', f_title, fmax, 'line', 'Fmax (MHz)', [f'{v:.0f}' for v in fmax])):
            fig, ax = plt.subplots(figsize=(7.2, 4))
            x = range(len(vals))
            if kind == 'bar':
                ax.bar(x, vals, color=SERIES, width=0.6)
            else:
                ax.plot(x, vals, color=SERIES, linewidth=2, marker='o', markersize=6)
            for i, (v, n) in enumerate(zip(vals, notes)):
                ax.annotate(n, (i, v), textcoords='offset points', xytext=(0, 6), ha='center', fontsize=9)
            ax.set_xticks(list(x), labels, fontsize=9)
            ax.set_ylabel(ylab)
            ax.set_ylim(0, max(vals) * 1.2)
            ax.set_title(title, loc='left', fontsize=11)
            ax.grid(axis='y', color=GRID)
            ax.set_axisbelow(True)
            for s in ('top', 'right'):
                ax.spines[s].set_visible(False)
            fig.tight_layout()
            fig.savefig(fname, dpi=120)
            plt.close(fig)
            print(f'plot_sweep: {fname}')
    except ImportError:
        svg_chart(stem + '_area.svg', a_title, labels, area, 'bar', 'cell area (library units)',
                  [r['flops'] + ' FF' for r in rows])
        svg_chart(stem + '_fmax.svg', f_title, labels, fmax, 'line', 'Fmax (MHz)',
                  [f'{v:.0f}' for v in fmax])
        made = [stem + '_area.svg', stem + '_fmax.svg']
        conv = shutil.which('rsvg-convert')
        if conv:                                   # PNG as well, when librsvg is installed
            for svg in list(made):
                png = svg[:-4] + '.png'
                if subprocess.run([conv, '-o', png, svg]).returncode == 0:
                    made.append(png)
        print('plot_sweep: ' + ' '.join(made) + ' (matplotlib not installed: SVG)')


if __name__ == '__main__':
    main()
