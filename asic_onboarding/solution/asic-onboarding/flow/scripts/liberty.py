"""flow/scripts/liberty.py -- minimal Liberty (.lib) reader for the flow helper scripts.

Used by lib2v.py (Verilog cell models for GLS) and lib2lef.py (placeholder LEF for the
Fusion Compiler bring-up library). It reads the generic Liberty syntax only:

    group_name ( args ) { ... }      -> Group(kind, args, attrs, groups)
    simple_attr : value ;            -> attrs[name] = value (string, quotes removed)
    complex_attr ( v1, v2 ) ;        -> attrs[name] = "v1, v2"

Comments, line continuations and quoted strings are handled; everything else (tables,
units) is kept as text. Nothing here knows about a particular library or design.
"""

import re

_TOKEN = re.compile(r'''
    (?P<ws>\s+|\\\n) |
    (?P<comment>/\*.*?\*/|//[^\n]*) |
    (?P<str>"(?:[^"\\]|\\.|\\\n)*") |
    (?P<punct>[(){}:;,]) |
    (?P<word>[^\s(){}:;,"]+)
''', re.S | re.X)


class Group:
    """One Liberty group: kind ('cell', 'pin', 'ff', ...), its arguments, attributes, children."""

    def __init__(self, kind, args):
        self.kind = kind
        self.args = args
        self.attrs = {}
        self.groups = []

    @property
    def name(self):
        return self.args[0] if self.args else ''

    def sub(self, kind):
        """All child groups of the given kind."""
        return [g for g in self.groups if g.kind == kind]

    def first(self, kind):
        lst = self.sub(kind)
        return lst[0] if lst else None


def _tokens(text):
    for m in _TOKEN.finditer(text):
        kind = m.lastgroup
        if kind in ('ws', 'comment'):
            continue
        val = m.group(kind)
        if kind == 'str':
            val = val[1:-1].replace('\\\n', '')
        yield kind, val


def parse(path):
    """Parse a Liberty file and return the top 'library' Group."""
    with open(path, encoding='utf-8', errors='replace') as f:
        toks = list(_tokens(f.read()))
    pos = 0

    def parse_body(group):
        nonlocal pos
        while pos < len(toks):
            kind, val = toks[pos]
            if val == '}':
                pos += 1
                return
            if val == ';':
                pos += 1
                continue
            name = val
            pos += 1
            if pos >= len(toks):
                return
            nxt = toks[pos][1]
            if nxt == ':':                       # simple attribute
                pos += 1
                parts = []
                while pos < len(toks) and toks[pos][1] not in (';', '}'):
                    parts.append(toks[pos][1])
                    pos += 1
                group.attrs[name] = ' '.join(parts)
            elif nxt == '(':                     # group or complex attribute
                pos += 1
                args, cur = [], []
                depth = 0
                while pos < len(toks):
                    v = toks[pos][1]
                    if v == '(':
                        depth += 1
                    elif v == ')':
                        if depth == 0:
                            break
                        depth -= 1
                    if v == ',' and depth == 0:
                        args.append(' '.join(cur))
                        cur = []
                    else:
                        cur.append(v)
                    pos += 1
                if cur:
                    args.append(' '.join(cur))
                pos += 1                          # ')'
                if pos < len(toks) and toks[pos][1] == '{':
                    pos += 1
                    child = Group(name, [a.strip() for a in args])
                    parse_body(child)
                    group.groups.append(child)
                else:
                    group.attrs[name] = ', '.join(a.strip() for a in args)
            else:
                # stray word: skip
                continue

    root = Group('root', [])
    parse_body(root)
    lib = root.first('library')
    if lib is None:
        raise ValueError(f'{path}: no library group')
    return lib


def pins(cell):
    """(name, direction, pin group) of every pin of a cell; a pin group with several
    names ('pin(A,B)') gives one entry per name. Standard cells have no buses."""
    out = []
    for p in cell.sub('pin'):
        for arg in p.args:
            for n in arg.split():               # old libraries write 'pin(A E)'
                out.append((n, p.attrs.get('direction', 'input'), p))
    return out
