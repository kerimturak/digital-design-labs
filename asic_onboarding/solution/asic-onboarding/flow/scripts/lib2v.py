#!/usr/bin/env python3
"""flow/scripts/lib2v.py -- zero-delay Verilog models of the cells of a Liberty library.

    $(PYTHON) lib2v.py <lib.lib> <out.v>

Gate-level simulation (make gls) needs a Verilog model of every library cell in the
netlist. Foundry kits ship them (sky130, SAED32: <lib>.v); a bring-up library such as
the Synopsys generic class.lib does not. This script writes them from the Liberty
description itself, which is exactly what synthesis used:

  * combinational output 'function'      -> assign (Liberty operators ' ! ^ & * space | +)
  * 'three_state' condition              -> assign out = cond ? 1'bz : function
  * ff (IQ, IQN) group                   -> always @(posedge clk or posedge clear/preset)
    with clocked_on, next_state, clear, preset (clear wins when both are active,
    unless clear_preset_var1 says otherwise)
  * latch group                          -> level-sensitive always block
  * cells with only a statetable         -> skipped (listed in the header)

The models are zero-delay and functional only (no specify blocks, no timing checks):
timing is the job of STA (Lab P2). Every state element is a 'reg', so VCS
+vcs+initreg+random gives it a random power-up value, like silicon.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import liberty  # noqa: E402

_FTOK = re.compile(r"\s*([A-Za-z_][A-Za-z0-9_\[\]\.]*|[01]|[()'!^&*|+])")


def func2v(expr, rename=None):
    """Translate a Liberty Boolean function to a fully parenthesized Verilog expression.
    Precedence (Liberty): ' and ! (NOT) > ^ (XOR) > & * space (AND) > | + (OR)."""
    rename = rename or {}
    toks, pos, s = [], 0, expr.strip()
    while pos < len(s):
        m = _FTOK.match(s, pos)
        if not m:
            raise ValueError(f'cannot parse function "{expr}" at "{s[pos:]}"')
        toks.append(m.group(1))
        pos = m.end()
    i = 0

    def peek():
        return toks[i] if i < len(toks) else None

    def take():
        nonlocal i
        i += 1
        return toks[i - 1]

    def p_or():
        t = p_and()
        while peek() in ('+', '|'):
            take()
            t = f'({t} | {p_and()})'
        return t

    def starts_operand(tok):
        return tok is not None and (tok in ('(', '!') or re.match(r'[A-Za-z_01]', tok))

    def p_and():
        t = p_xor()
        while peek() in ('*', '&') or starts_operand(peek()):
            if peek() in ('*', '&'):
                take()
            t = f'({t} & {p_xor()})'
        return t

    def p_xor():
        t = p_not()
        while peek() == '^':
            take()
            t = f'({t} ^ {p_not()})'
        return t

    def p_not():
        if peek() == '!':
            take()
            return f'(~{p_not()})'
        t = p_prim()
        while peek() == "'":
            take()
            t = f'(~{t})'
        return t

    def p_prim():
        tok = take()
        if tok == '(':
            t = p_or()
            if take() != ')':
                raise ValueError(f'unbalanced parentheses in "{expr}"')
            return t
        if tok in ('0', '1'):
            return "1'b" + tok
        return rename.get(tok, tok)

    out = p_or()
    if i != len(toks):
        raise ValueError(f'trailing tokens in function "{expr}"')
    return out


def cell_model(cell):
    """Verilog module text for one cell, or None if it cannot be modelled."""
    pins = liberty.pins(cell)
    ins = [n for n, d, _ in pins if d == 'input']
    outs = [n for n, d, _ in pins if d == 'output']
    ios = [n for n, d, _ in pins if d == 'inout']
    seq = cell.first('ff') or cell.first('latch')
    if not outs and not ios:
        return None
    body = []
    rename = {}
    if seq is not None:
        iq, iqn = (seq.args + ['', ''])[:2]
        iq, iqn = iq.strip(), iqn.strip()
        rename = {iq: 'IQ_', iqn: 'IQN_'}
        body.append('  reg IQ_;')
        clr = seq.attrs.get('clear')
        pre = seq.attrs.get('preset')
        zero = "1'b0"
        body.append(f'  wire clr_ = {func2v(clr) if clr else zero};')
        body.append(f'  wire pre_ = {func2v(pre) if pre else zero};')
        both = seq.attrs.get('clear_preset_var1', 'L')   # value of IQ when both are active
        both_v = {'L': "1'b0", 'H': "1'b1", 'X': "1'bx"}.get(both.strip('"'), "1'b0")
        if cell.first('ff') is not None:
            body.append(f"  wire clk_ = {func2v(seq.attrs['clocked_on'])};")
            body.append(f"  wire nxt_ = {func2v(seq.attrs['next_state'])};")
            body += ['  always @(posedge clk_ or posedge clr_ or posedge pre_)',
                     f'    if (clr_ && pre_) IQ_ <= {both_v};',
                     "    else if (clr_)   IQ_ <= 1'b0;",
                     "    else if (pre_)   IQ_ <= 1'b1;",
                     '    else             IQ_ <= nxt_;']
        else:
            body.append(f"  wire en_  = {func2v(seq.attrs['enable'])};")
            body.append(f"  wire din_ = {func2v(seq.attrs['data_in'])};")
            body += ['  always @(*)',
                     f'    if (clr_ && pre_) IQ_ = {both_v};',
                     "    else if (clr_)   IQ_ = 1'b0;",
                     "    else if (pre_)   IQ_ = 1'b1;",
                     '    else if (en_)    IQ_ = din_;']
        both_n = seq.attrs.get('clear_preset_var2', 'H')
        both_nv = {'L': "1'b0", 'H': "1'b1", 'X': "1'bx"}.get(both_n.strip('"'), "1'b1")
        body.append(f'  wire IQN_ = (clr_ && pre_) ? {both_nv} : ~IQ_;')
    elif cell.first('statetable') is not None:
        return None
    for n, d, p in pins:
        if d not in ('output', 'inout'):
            continue
        f = p.attrs.get('function')
        if not f:
            if d == 'output':
                return None
            continue
        v = func2v(f, rename)
        ts = p.attrs.get('three_state')
        if ts:
            v = f"({func2v(ts, rename)}) ? 1'bz : {v}"
        body.append(f'  assign {n} = {v};')
    ports = [n for n, _, _ in pins]
    hdr = [f'module {cell.name} ({", ".join(ports)});']
    if ins:
        hdr.append(f'  input  {", ".join(ins)};')
    if outs:
        hdr.append(f'  output {", ".join(outs)};')
    if ios:
        hdr.append(f'  inout  {", ".join(ios)};')
    return '\n'.join(['`celldefine'] + hdr + body + ['endmodule', '`endcelldefine', ''])


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('lib')
    ap.add_argument('out')
    a = ap.parse_args()
    lib = liberty.parse(a.lib)
    mods, skipped = [], []
    for cell in lib.sub('cell'):
        try:
            m = cell_model(cell)
        except (ValueError, KeyError) as e:
            m = None
            print(f'lib2v: {cell.name}: {e}', file=sys.stderr)
        if m is None:
            skipped.append(cell.name)
        else:
            mods.append(m)
    with open(a.out, 'w') as f:
        f.write(f'// generated by flow/scripts/lib2v.py from {os.path.basename(a.lib)} '
                f'(library {lib.name}) -- zero-delay functional cell models for GLS\n')
        if skipped:
            f.write(f'// not modelled (no function / statetable only): {" ".join(skipped)}\n')
        f.write('`timescale 1ns/1ps\n\n')
        f.write('\n'.join(mods))
    print(f'lib2v: {len(mods)} cell models -> {a.out}' +
          (f' ({len(skipped)} skipped: {" ".join(skipped)})' if skipped else ''))


if __name__ == '__main__':
    main()
