import Foundation

/// **One source a dictionary is made from, as the builder runs it** — a
/// Wiktionary edition (`Edition`), VESUM (`Vesum`), the Albanian analyzer
/// (`Uniparser`) or LanguageTool's Romanian (`LanguageToolRomanian`): its
/// name on the command line, what the file says of it, its licence, how
/// many input files it reads and how it reads them.
struct Source {
    let name: String
    /// Where the words come from, as the file and the acknowledgement name it.
    let description: String
    let licence: String
    /// The LGPL asks a changed copy to say what was changed, and when.
    let isLGPL: Bool
    let inputCount: Int
    let read: (_ inputs: [Lines], _ language: String) -> [DictionaryFile.Entry]

    static func named(_ name: String) -> Source? {
        if let edition = Edition.named(name) {
            return Source(name: name, description: edition.source, licence: "CC BY-SA 4.0", isLGPL: false, inputCount: 1) { inputs, language in
                entries(of: edition, from: inputs[0], language: language)
            }
        }
        switch name {
        case Vesum.name:
            return Source(name: name, description: Vesum.source, licence: Vesum.licence, isLGPL: true, inputCount: 1) { inputs, _ in
                Vesum.entries(inputs[0])
            }
        case Uniparser.name:
            return Source(name: name, description: Uniparser.source, licence: Uniparser.licence, isLGPL: false, inputCount: 2) { inputs, _ in
                Uniparser.entries(paradigms: inputs[0], lexemes: inputs[1])
            }
        case LanguageToolRomanian.name:
            return Source(name: name, description: LanguageToolRomanian.source, licence: LanguageToolRomanian.licence, isLGPL: true, inputCount: 1) { inputs, _ in
                LanguageToolRomanian.entries(inputs[0])
            }
        default:
            return nil
        }
    }

    static var names: [String] { Edition.names + [Vesum.name, Uniparser.name, LanguageToolRomanian.name] }

    /// An edition's entries of the language, each once.
    private static func entries(of edition: Edition, from lines: Lines, language: String) -> [DictionaryFile.Entry] {
        var seen = Set<DictionaryFile.Entry>()
        var entries: [DictionaryFile.Entry] = []
        // A line naming the language's code nowhere is no entry of it: the
        // English edition's extract holds every language, and parsing each
        // of its lines takes most of the time.
        let languageMark = "\"\(language)\""
        for line in lines {
            guard line.contains(languageMark),
                  let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entry = edition.entry(object, language),
                  seen.insert(entry).inserted
            else { continue }
            entries.append(entry)
        }
        return entries
    }
}
