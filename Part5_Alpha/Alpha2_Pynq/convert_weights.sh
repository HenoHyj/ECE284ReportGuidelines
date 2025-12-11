#!/bin/bash
# Convert weight .txt files to .mem format for $readmemb
# Removes the 3 header comment lines, keeps 8 data lines

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../../software/part1"
DST_DIR="$SCRIPT_DIR/data"

mkdir -p "$DST_DIR"

for i in 0 1 2 3 4 5 6 7 8; do
  echo "Converting weight_$i.txt -> weight_$i.mem"
  tail -n +4 "$SRC_DIR/weight_$i.txt" | head -8 > "$DST_DIR/weight_$i.mem"
done

echo "Done. Created 9 .mem files in $DST_DIR"
