import Foundation
import SQLite3

// **Makes one language's dictionary file from its source.**
// Reads, on standard input, kaikki.org's extract of a Wiktionary edition
// (wiktextract's JSON lines, uncompressed) or VESUM's word forms
// (`Tools/MorfologikDump`'s lines), keeps each word's base form with its
// part of speech and, for a noun, its gender, number and plural
// (`Edition`, `Vesum`), and writes them as the SQLite file the app reads
// (`DictionaryFile`). Built and run by `build-dictionary.sh`.
//
//   build <language code> <edition | vesum> <output file> <source date>
//
// Every inflected form of the source is left out: a card holds a base
// form, and a noun written in the plural is found through its base form's
// plural.

let arguments = CommandLine.arguments
let sources = Edition.names + [Vesum.name]
guard arguments.count == 5, sources.contains(arguments[2]) else {
    FileHandle.standardError.write(Data("usage: build <language code> <source: \(sources.joined(separator: "|"))> <output file> <source date>\n".utf8))
    exit(2)
}
let language = arguments[1], name = arguments[2], output = arguments[3], sourceDate = arguments[4]

/// Standard input, a line at a time, counted.
final class Lines: Sequence, IteratorProtocol {
    private(set) var count = 0

    func next() -> String? {
        guard let line = readLine(strippingNewline: true) else { return nil }
        count += 1
        return line
    }
}

let lines = Lines()
var entries: [DictionaryFile.Entry] = []
var meta: [String: String]
if let edition = Edition.named(name) {
    meta = ["source": edition.source, "licence": "CC BY-SA 4.0"]
    var seen = Set<DictionaryFile.Entry>()
    // A line naming the language's code nowhere is no entry of it: the
    // English edition's extract holds every language, and parsing each of
    // its lines takes most of the time.
    let languageMark = "\"\(language)\""
    while let line = lines.next() {
        guard line.contains(languageMark),
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = edition.entry(object, language),
              seen.insert(entry).inserted
        else { continue }
        entries.append(entry)
    }
} else {
    // The LGPL asks a changed copy to say what was changed, and when.
    meta = [
        "source": Vesum.source,
        "licence": Vesum.licence,
        "changes": "Leleka keeps each base form with its part of speech, a noun's gender, number and plural, written as Leleka's dictionary file; made \(Date.now.formatted(.iso8601.year().month().day()))",
    ]
    entries = Vesum.entries(lines)
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
print("▸ \(language) from \(name): \(lines.count) lines read, \(entries.count) words kept — \(nouns.count) nouns, \(nouns.filter { $0.gender != nil }.count) with a gender, \(nouns.filter { $0.plural != nil }.count) with a plural")
