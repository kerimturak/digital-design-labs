#!/usr/bin/env bash
# flist_expand.sh -- flatten a SystemVerilog file list (.f) for tools that do not read -f.
#
# Usage: flist_expand.sh [--files|--incdirs|--defines|--flat] <list.f> [<list.f> ...]
#
#   --files    (default) one absolute source file per line, compile order
#   --incdirs  one include directory per line
#   --defines  one define per line (NAME or NAME=VALUE), from +define+ entries
#   --flat     a flat file list: +incdir+ lines, +define+ lines, then the source files;
#              readable with -f by any tool (VCS, VC Static, Verilator, ...)
#
# File-list format (SPEC 2.2): one entry per line, // comments (whole line or trailing),
# besides file names only +incdir+<dir>, +define+<N>[=<V>] and nested -f <list>.
# ${VAR} / $VAR environment references (normally ${REPO_ROOT}) are substituted; an unset
# variable is an error. Nested -f lists are followed recursively (-F too: its relative
# paths are resolved against the list's own directory). Duplicates are dropped, the
# first occurrence wins. Relative paths (against the rules) are resolved against the
# current directory, like the tools do, with a warning. A missing file is an error.
# Exit code: 0 on success, 1 on any error (messages on stderr).

set -u

mode=files
lists=()
for arg in "$@"; do
  case "$arg" in
    --files|--incdirs|--defines|--flat) mode=${arg#--} ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "flist_expand: unknown option $arg" >&2; exit 1 ;;
    *) lists+=("$arg") ;;
  esac
done
[ ${#lists[@]} -gt 0 ] || { echo "usage: flist_expand.sh [--files|--incdirs|--defines|--flat] <list.f>..." >&2; exit 1; }

errors=0
declare -A seen_file seen_inc seen_def seen_list
files=(); incdirs=(); defines=()

err()  { echo "flist_expand: ERROR: $*" >&2; errors=$((errors + 1)); }
warn() { echo "flist_expand: WARNING: $*" >&2; }

# Substitute ${VAR} and $VAR from the environment.
subst_env() {
  local s=$1 out="" name
  while [[ $s =~ ^([^\$]*)\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))(.*)$ ]]; do
    name=${BASH_REMATCH[3]:-${BASH_REMATCH[4]}}
    if [ -z "${!name+x}" ]; then
      err "environment variable \$$name is not set (in '$1')"
      return 1
    fi
    out+="${BASH_REMATCH[1]}${!name}"
    s=${BASH_REMATCH[5]}
  done
  printf '%s' "$out$s"
}

# Make a path absolute. $2 = base directory for relative paths, $3 = context for warnings.
abs_path() {
  local p=$1 base=$2
  if [[ $p != /* ]]; then
    warn "relative path '$p' in $3 (file lists must start every path with \${REPO_ROOT})"
    p="$base/$p"
  fi
  # Normalise without requiring the path to exist.
  realpath -m -- "$p"
}

expand() {
  local list=$1 depth=$2 relbase=$3 line tok i toks
  if [ "$depth" -gt 20 ]; then err "nesting deeper than 20 at $list (recursive -f?)"; return; fi
  if [ ! -f "$list" ]; then err "file list not found: $list"; return; fi
  if [ -n "${seen_list[$list]+x}" ]; then return; fi   # included twice: first wins
  seen_list[$list]=1
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%$'\r'}
    # Strip // comments: whole line, or preceded by white space.
    if [[ $line =~ ^[[:space:]]*// ]]; then continue; fi
    line=$(sed -E 's#[[:space:]]+//.*$##' <<<"$line")
    read -ra toks <<<"$line"
    i=0
    while [ $i -lt ${#toks[@]} ]; do
      tok=${toks[$i]}
      tok=$(subst_env "$tok") || { errors=$((errors + 1)); i=$((i + 1)); continue; }
      case "$tok" in
        -f|-F)
          i=$((i + 1))
          local sub=${toks[$i]:-}
          [ -n "$sub" ] || { err "$list: '$tok' without a file name"; break; }
          sub=$(subst_env "$sub") || { errors=$((errors + 1)); i=$((i + 1)); continue; }
          local base=$PWD
          [ "$tok" = "-F" ] && base=$(dirname "$list")
          sub=$(abs_path "$sub" "$base" "$list")
          expand "$sub" $((depth + 1)) "$base"
          ;;
        +incdir+*)
          local d rest=${tok#+incdir+}
          IFS='+' read -ra ds <<<"$rest"
          for d in "${ds[@]}"; do
            [ -n "$d" ] || continue
            d=$(abs_path "$d" "$relbase" "$list")
            [ -d "$d" ] || err "$list: include directory not found: $d"
            if [ -z "${seen_inc[$d]+x}" ]; then seen_inc[$d]=1; incdirs+=("$d"); fi
          done
          ;;
        +define+*)
          local def rest=${tok#+define+}
          IFS='+' read -ra defs <<<"$rest"
          for def in "${defs[@]}"; do
            [ -n "$def" ] || continue
            if [ -z "${seen_def[$def]+x}" ]; then seen_def[$def]=1; defines+=("$def"); fi
          done
          ;;
        -*|+*)
          warn "$list: option '$tok' ignored (only +incdir+, +define+ and -f are allowed)"
          ;;
        *)
          local f
          f=$(abs_path "$tok" "$relbase" "$list")
          [ -f "$f" ] || err "$list: source file not found: $f"
          if [ -z "${seen_file[$f]+x}" ]; then seen_file[$f]=1; files+=("$f"); fi
          ;;
      esac
      i=$((i + 1))
    done
  done <"$list"
}

for l in "${lists[@]}"; do
  l=$(realpath -m -- "$l")
  expand "$l" 0 "$PWD"
done

case "$mode" in
  files)   [ ${#files[@]}   -eq 0 ] || printf '%s\n' "${files[@]}" ;;
  incdirs) [ ${#incdirs[@]} -eq 0 ] || printf '%s\n' "${incdirs[@]}" ;;
  defines) [ ${#defines[@]} -eq 0 ] || printf '%s\n' "${defines[@]}" ;;
  flat)
    for d in ${incdirs[@]+"${incdirs[@]}"}; do printf '+incdir+%s\n' "$d"; done
    for d in ${defines[@]+"${defines[@]}"}; do printf '+define+%s\n' "$d"; done
    for f in ${files[@]+"${files[@]}"};     do printf '%s\n' "$f"; done
    ;;
esac

[ $errors -eq 0 ] || exit 1
exit 0
