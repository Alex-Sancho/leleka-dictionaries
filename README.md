# Leleka's Ukrainian dictionary

The Ukrainian dictionary inside Leleka, an iPhone and iPad app for learning a language with a teacher, and everything needed to make it again. Leleka uses it to guess a word card's part of speech and, for a noun, its gender, number and plural.

The dictionary is a modified version of **VESUM** (Великий електронний словник української мови), the large electronic dictionary of Ukrainian by the [brown-uk](https://github.com/brown-uk/dict_uk) project, taken from its LanguageTool package `ua.net.nlp:morfologik-ukrainian-lt` 6.6.9 (Maven Central), which is distributed under the GNU Lesser General Public License, version 2.1 or later. This repository is published to meet that licence.

## What is here

| Path | What it is |
|---|---|
| `source/morfologik-ukrainian-lt-6.6.9.jar` | VESUM's package as published, unchanged |
| `tools/MorfologikDump/` | Reads the package's Morfologik automaton (CFSA2) and writes every word form as a line: form, base form, tags |
| `tools/DictionaryBuilder/` | Keeps each base form with its part of speech and, for a noun, its gender, number and nominative plural (`Vesum.swift`), and writes Leleka's dictionary file (`DictionaryFile.swift`); `Edition.swift` reads Wiktionary for Leleka's other languages and is here because the builder compiles with it |
| `build.sh` | Makes the file from the package with the tools |
| `dictionary/uk.sqlite.lzma` | The file exactly as Leleka carries it from 0.1 (build 5), LZMA-compressed |
| `COPYING.LESSER` | The GNU Lesser General Public License, version 2.1 |

## What was changed

VESUM lists every form of every word with its grammatical tags. Leleka's file keeps, for each base form, only its part of speech (each closed class – a pronoun, a numeral, a conjunction, an interjection, a preposition, a particle – a class of its own; a predicative and a parenthetical word an adverb) and, for a noun, its gender (where it has one only), its number (where it has one only) and its nominative plural (where VESUM gives one as common as any other). Calques, spellings outside the current rules, names and abbreviations are left out. The result is written as a SQLite file in Leleka's own shape. The file's `meta` table records its source, its licence and these changes with the date they were made (1 November 2026).

## Making it again

On macOS with Xcode or its command line tools:

```
./build.sh
```

It writes `out/uk.sqlite` and `out/uk.sqlite.lzma`. The words are the same as in `dictionary/uk.sqlite.lzma`; only the date in `meta` follows the day it is run. To read the file Leleka carries:

```
compression_tool -decode -a lzma -i dictionary/uk.sqlite.lzma -o uk.sqlite
```

## Licence

Everything here – the dictionary file, VESUM's package and the tools – is distributed under the GNU Lesser General Public License, version 2.1 or (at your option) any later version; see `COPYING.LESSER`. The rest of Leleka is not part of this work.

VESUM's words are by the authors of the brown-uk project; see [github.com/brown-uk/dict_uk](https://github.com/brown-uk/dict_uk).
