#!/bin/bash
#
# Makes Leleka's Ukrainian dictionary file from VESUM's package, as the
# app's own build does.
#
#   ./build.sh
#
# Needs macOS with Xcode or its command line tools (swiftc, SQLite,
# compression_tool). Writes `out/uk.sqlite` and `out/uk.sqlite.lzma`, the
# file compressed as Leleka carries it; the file in `dictionary/` is the
# one in the app. The two differ only in the date the file records in its
# `meta` table ("changes").
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="$HERE/source/morfologik-ukrainian-lt-6.6.9.jar"
OUT="$HERE/out"
mkdir -p "$OUT"

echo "▸ building the tools"
xcrun swiftc -O "$HERE/tools/MorfologikDump/main.swift" -o "$OUT/dump"
xcrun swiftc -O "$HERE"/tools/DictionaryBuilder/*.swift -o "$OUT/build"

echo "▸ reading VESUM's automaton"
unzip -p "$PACKAGE" org/languagetool/resource/uk/ukrainian.dict > "$OUT/ukrainian.dict"
"$OUT/dump" "$OUT/ukrainian.dict" | "$OUT/build" uk vesum "$OUT/uk.sqlite" 2025-06-10

rm -f "$OUT/uk.sqlite.lzma"
compression_tool -encode -a lzma -i "$OUT/uk.sqlite" -o "$OUT/uk.sqlite.lzma"
echo "▸ $OUT/uk.sqlite, $OUT/uk.sqlite.lzma"
