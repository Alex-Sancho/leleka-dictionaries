import Foundation
import SQLite3

// **Makes one language's dictionary file from its sources.**
// Reads each source (`Source`): kaikki.org's extract of a Wiktionary
// edition (wiktextract's JSON lines, uncompressed), VESUM's or
// LanguageTool's word forms (`Tools/MorfologikDump`'s lines), or the
// Albanian analyzer's dictionary (its inflection classes, then its
// lexemes); keeps each word's base form with its part of speech and, for
// a noun, its gender, number and plural; and writes them as the SQLite
// file the app reads (`DictionaryFile`). Built and run by
// `build-dictionary.sh`.
//
//   build <language code> <source[+source…]> <output file> <source date> [input …]
//
// Several sources joined by "+" ("vi+en", "en+languagetool-ro") make the
// dictionary of a language no one source describes whole. They are read
// in that order, each from its input files (the analyzer reads two, any
// other one); one source reading one input may read standard input
// instead. A later source adds only the words the earlier ones lack,
// whole: a word the first source has keeps its readings, so a later
// source's stray reading of it (a noun made of an adjective) never comes
// in, and a noun keeps one source's gender and plural.
//
// Every inflected form of the source is left out: a card holds a base
// form, and a noun written in the plural is found through its base form's
// plural.

let arguments = CommandLine.arguments
let usage = "usage: build <language code> <source: \(Source.names.joined(separator: "|")), several joined by \"+\"> <output file> <source date> [input …]\n"
func refuse(_ message: String) -> Never {
    FileHandle.standardError.write(Data(message.utf8))
    exit(2)
}
guard arguments.count >= 5 else { refuse(usage) }
let language = arguments[1], name = arguments[2], output = arguments[3], sourceDate = arguments[4]
let inputs = Array(arguments.dropFirst(5))
let names = name.split(separator: "+").map(String.init)
let sources = names.compactMap(Source.named)
guard !sources.isEmpty, sources.count == names.count else { refuse(usage) }
let inputCount = sources.reduce(0) { $0 + $1.inputCount }
guard inputs.count == inputCount || (inputs.isEmpty && inputCount == 1) else {
    refuse("✗ \(name) reads \(inputCount) input file(s), \(inputs.count) given; standard input stands for one\n")
}

/// One input's lines, a line at a time, counted: a file, or standard input.
final class Lines: Sequence, IteratorProtocol {
    private(set) var count = 0
    private let file: UnsafeMutablePointer<FILE>
    private var buffer: UnsafeMutablePointer<CChar>?
    private var capacity = 0

    init(path: String?) {
        guard let path else { file = stdin; return }
        guard let opened = fopen(path, "r") else { refuse("✗ cannot read \(path)\n") }
        file = opened
    }

    func next() -> String? {
        let length = getline(&buffer, &capacity, file)
        guard length >= 0, let buffer else { return nil }
        count += 1
        var line = String(cString: buffer)
        if line.hasSuffix("\n") { line.removeLast() }
        return line
    }
}

var entries: [DictionaryFile.Entry] = []
var linesRead = 0
// The words the earlier sources gave, by key.
var given = Set<String>()
var nextInput = 0
for source in sources {
    let lines = inputs.isEmpty ? [Lines(path: nil)]
        : inputs[nextInput..<(nextInput + source.inputCount)].map { Lines(path: $0) }
    nextInput += source.inputCount
    let added = source.read(lines, language).filter { !given.contains(DictionaryFile.key($0.word)) }
    given.formUnion(added.map { DictionaryFile.key($0.word) })
    entries += added
    let read = lines.reduce(0) { $0 + $1.count }
    linesRead += read
    print("▸ \(language) from \(source.name): \(read) lines read, \(added.count) words added")
}

var meta = [
    "source": sources.map(\.description).joined(separator: "; "),
    "licence": sources.map(\.licence).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: "; "),
]
if sources.contains(where: \.isLGPL) {
    meta["changes"] = "Leleka keeps each base form with its part of speech, a noun's gender, number and plural, written as Leleka's dictionary file; made \(Date.now.formatted(.iso8601.year().month().day()))"
}

do {
    try DictionaryFile.write(entries, to: output, meta: meta.merging([
        "format": String(DictionaryFile.format),
        "language": language,
        "edition": name,
        "extracted": sourceDate,
        "revision": String(DictionaryFile.revision),
    ]) { $1 })
} catch {
    FileHandle.standardError.write(Data("✗ \(error)\n".utf8))
    exit(1)
}
let nouns = entries.filter { $0.partOfSpeech == "noun" }
print("▸ \(language) from \(name): \(linesRead) lines read, \(entries.count) words kept — \(nouns.count) nouns, \(nouns.filter { $0.gender != nil }.count) with a gender, \(nouns.filter { $0.plural != nil }.count) with a plural")
