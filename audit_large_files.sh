#!/usr/bin/env bash
set -euo pipefail

threshold="${1:-50M}"

echo "Scanning working tree for files > $threshold..."
find . -type f -not -path "./.git/*" -size +"$threshold" -print | sed 's|^./||' || true

printf "\nTop 30 largest blobs in Git history (bytes\tpath):\n"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git rev-list --objects --all >"$tmpdir/objects.txt"
cut -d' ' -f1 "$tmpdir/objects.txt" |
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' >"$tmpdir/sizes.txt"

awk '
  FNR==NR && $1=="blob" { size[$2]=$3; next }
  { sha=$1; $1=""; sub(/^ /,""); path=$0; if (sha in size) print size[sha] "\t" path }
' "$tmpdir/sizes.txt" "$tmpdir/objects.txt" | sort -nr | head -n 30 || true
