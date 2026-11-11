# Leleka's dictionaries made from LGPL sources

The Ukrainian and Romanian dictionaries of Leleka, an iPhone and iPad app for learning a language with a teacher, and everything needed to make them again. Leleka uses a language's dictionary to guess a word card's part of speech and, for a noun, its gender, number and plural.

Both are made in whole or in part from sources distributed under the GNU Lesser General Public License, version 2.1 or later, and this repository is published to meet that licence:

- **Ukrainian** – a modified version of **VESUM** (Великий електронний словник української мови), the large electronic dictionary of Ukrainian by the [brown-uk](https://github.com/brown-uk/dict_uk) project, taken from its LanguageTool package `ua.net.nlp:morfologik-ukrainian-lt` 6.6.9 (Maven Central).
- **Romanian** – the English Wiktionary's Romanian entries (CC BY-SA 4.0), with the words they lack taken from **LanguageTool's Romanian dictionary**, developed by Ionuț Păduraru ([archeus.ro](http://www.archeus.ro)) and released with [LanguageTool](https://github.com/languagetool-org/languagetool) under the LGPL.

## What is here

| Path | What it is |
|---|---|
| `source/morfologik-ukrainian-lt-6.6.9.jar` | VESUM's package as published, unchanged |
| `source/romanian.dict`, `source/romanian.info`, `source/romanian-README.txt` | LanguageTool's Romanian dictionary as published in its repository, unchanged, with its note on authorship and licence |
| `tools/MorfologikDump/` | Reads a Morfologik automaton (CFSA2, as VESUM's; FSA5, as LanguageTool's Romanian) and writes every word form as a line: form, base form, tags |
| `tools/DictionaryBuilder/` | Keeps each base form with its part of speech and, for a noun, its gender, number and nominative plural, and writes Leleka's dictionary file (`DictionaryFile.swift`): VESUM's reading in `Vesum.swift`, LanguageTool's Romanian in `LanguageToolRomanian.swift`, Wiktionary's in `Edition.swift`; `Source.swift` and `main.swift` run them, a later source adding only the words the earlier lack. `Uniparser.swift` reads the source of Leleka's Albanian dictionary (MIT) and is here because the builder compiles with it |
| `build.sh` | Makes either file from its sources with the tools |
| `dictionary/uk.sqlite.lzma`, `dictionary/ro.sqlite.lzma` | The files exactly as Leleka downloads them, LZMA-compressed |
| `COPYING.LESSER` | The GNU Lesser General Public License, version 2.1 |

## What was changed

VESUM and LanguageTool's Romanian dictionary list every form of every word with its grammatical tags. Leleka's file keeps, for each base form, only its part of speech (each closed class – a pronoun, a numeral, a conjunction, an interjection, a preposition, a particle, an article – a class of its own) and, for a noun, its gender (where it has one only), its number (where it has one only) and its nominative plural. Names are left out; from VESUM also calques, spellings outside the current rules and abbreviations. Of LanguageTool's Romanian only the words the English Wiktionary's Romanian lacks are kept. The result is written as a SQLite file in Leleka's own shape. Each file's `meta` table records its sources, their licences and these changes with the date they were made.

## Making them again

On macOS with Xcode or its command line tools:

```
./build.sh uk
./build.sh ro raw-wiktextract-data.jsonl.gz
```

Romanian needs kaikki.org's extract of the English Wiktionary ([kaikki.org/dictionary/rawdata.html](https://kaikki.org/dictionary/rawdata.html), about 3 GB); Leleka's file was made from the extract of 30 October 2026, and a later one gives somewhat different words. Each writes `out/<language>.sqlite` and `out/<language>.sqlite.lzma`. To read a file Leleka downloads:

```
compression_tool -decode -a lzma -i dictionary/uk.sqlite.lzma -o uk.sqlite
```

## Licence

VESUM's package, LanguageTool's Romanian dictionary, the tools, the Ukrainian dictionary file and the words of the Romanian file taken from LanguageTool are distributed under the GNU Lesser General Public License, version 2.1 or (at your option) any later version; see `COPYING.LESSER`. The words of the Romanian file taken from Wiktionary are under the Creative Commons Attribution-ShareAlike 4.0 International licence ([creativecommons.org/licenses/by-sa/4.0](https://creativecommons.org/licenses/by-sa/4.0/)); their authors are listed in each entry's history on Wiktionary, and they were extracted with wiktextract by Tatu Ylönen and taken from kaikki.org. The rest of Leleka is not part of this work.

VESUM's words are by the authors of the brown-uk project; see [github.com/brown-uk/dict_uk](https://github.com/brown-uk/dict_uk).
