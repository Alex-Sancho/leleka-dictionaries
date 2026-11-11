#!/bin/bash
#
# Makes Leleka's Ukrainian or Romanian dictionary file, as the app's own
# build does.
#
#   ./build.sh uk
#   ./build.sh ro <raw-wiktextract-data.jsonl.gz>
#
# Ukrainian is made from VESUM's package in `source/` alone. Romanian is
# made from the English Wiktionary's Romanian entries first – kaikki.org's
# extract of the English Wiktionary (kaikki.org/dictionary/rawdata.html,
# about 3 GB; Leleka's file used the extract of 30 October 2026) – and
# LanguageTool's Romanian dictionary in `source/`, which adds the words
# the English Wiktionary lacks.
#
# Needs macOS with Xcode or its command line tools (swiftc, SQLite,
# compression_tool). Writes `out/<language>.sqlite` and
# `out/<language>.sqlite.lzma`, the file compressed as Leleka carries it;
# the files in `dictionary/` are the ones Leleka downloads. A Ukrainian
# file made again differs from it only in the date it records in its
# `meta` table ("changes"); a Romanian one, also where a later Wiktionary
# extract differs.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
LANGUAGE="${1:-}"
mkdir -p "$OUT"

echo "▸ building the tools"
xcrun swiftc -O "$HERE/tools/MorfologikDump/main.swift" -o "$OUT/dump"
xcrun swiftc -O "$HERE"/tools/DictionaryBuilder/*.swift -o "$OUT/build"

case "$LANGUAGE" in
  uk)
    echo "▸ reading VESUM's automaton"
    unzip -p "$HERE/source/morfologik-ukrainian-lt-6.6.9.jar" org/languagetool/resource/uk/ukrainian.dict > "$OUT/ukrainian.dict"
    "$OUT/dump" "$OUT/ukrainian.dict" | "$OUT/build" uk vesum "$OUT/uk.sqlite" 2025-06-10
    ;;
  ro)
    EXTRACT="${2:-}"
    [ -f "$EXTRACT" ] || { echo "✗ give the English Wiktionary's extract: ./build.sh ro <raw-wiktextract-data.jsonl.gz>"; exit 2; }
    echo "▸ reading the English Wiktionary's Romanian, then LanguageTool's automaton"
    PIPES="$(mktemp -d)"
    trap 'rm -rf "$PIPES"' EXIT
    mkfifo "$PIPES/en" "$PIPES/lt"
    gzip -dc "$EXTRACT" > "$PIPES/en" &
    "$OUT/dump" "$HERE/source/romanian.dict" > "$PIPES/lt" &
    "$OUT/build" ro en+languagetool-ro "$OUT/ro.sqlite" 2026-10-30 "$PIPES/en" "$PIPES/lt"
    wait
    ;;
  *)
    sed -n '6,7p' "$0"; exit 2
    ;;
esac

rm -f "$OUT/$LANGUAGE.sqlite.lzma"
compression_tool -encode -a lzma -i "$OUT/$LANGUAGE.sqlite" -o "$OUT/$LANGUAGE.sqlite.lzma"
echo "▸ $OUT/$LANGUAGE.sqlite, $OUT/$LANGUAGE.sqlite.lzma"
