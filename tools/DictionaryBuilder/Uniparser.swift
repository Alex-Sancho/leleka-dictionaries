import Foundation

/// **The Albanian morphological analyzer's grammatical dictionary**
/// (github.com/timarkh/uniparser-grammar-albanian, MIT), written in the
/// uniparser-morph format: a lexeme a block — its base form (`lex`), its
/// stems (`stem`, numbered from 0 and split by "|", spelling variants by
/// "//"), its tags (`gramm`: part of speech, gender, "nonst" for a
/// non-standard form), its inflection classes (`paradigm`); and the
/// classes themselves in `paradigms.txt` — each ending with its tags, a
/// stem named by its number ("<0>.").
///
/// Albanian's words are read here rather than from the English
/// Wiktionary: kaikki.org extracts no Albanian edition, and the English
/// one describes about 7 500 Albanian nouns where this dictionary
/// describes about 28 600, each with its gender.
enum Uniparser {
    static let name = "uniparser"
    static let source = "uniparser-grammar-albanian (github.com/timarkh/uniparser-grammar-albanian)"
    static let licence = "MIT"

    /// The base forms the lexemes describe — a noun with its gender and
    /// its plural, the nominative indefinite plural its inflection class
    /// gives; plural only when its classes give only plural forms; another
    /// part of speech bare. A name (a capital letter first), an
    /// abbreviation and a non-standard lexeme are left out.
    static func entries(paradigms paradigmLines: some Sequence<String>, lexemes lexemeLines: some Sequence<String>) -> [DictionaryFile.Entry] {
        let classes = inflectionClasses(paradigmLines)
        var entries: [DictionaryFile.Entry] = []
        for lexeme in blocks(lexemeLines, marker: "-lexeme") {
            guard let word = lexeme["lex"]?.first, let first = word.first, !first.isUppercase,
                  let tags = lexeme["gramm"]?.first?.split(separator: ",").map(String.init),
                  let partOfSpeech = partsOfSpeech[tags.first ?? ""],
                  !tags.contains("nonst"), !tags.contains("abbr")
            else { continue }
            guard partOfSpeech == "noun" else {
                entries.append(DictionaryFile.Entry(word: word, partOfSpeech: partOfSpeech, gender: nil, number: nil, plural: nil))
                continue
            }
            let stems = (lexeme["stem"]?.first ?? "").split(separator: "|", omittingEmptySubsequences: false).map { stem in
                // A stem's spelling variants: the first is the standard one.
                String(stem.split(separator: "/").first ?? "").replacingOccurrences(of: ".", with: "")
            }
            let lexemeClasses = (lexeme["paradigm"] ?? []).compactMap { classes[$0] }
            let plural = lexemeClasses.lazy.compactMap { $0.plural.flatMap { $0.form(from: stems) } }.first
            let pluralOnly = !lexemeClasses.isEmpty && lexemeClasses.allSatisfy(\.isPluralOnly)
            entries.append(DictionaryFile.Entry(
                word: word,
                partOfSpeech: "noun",
                gender: genders[tags.dropFirst().first ?? ""],
                number: pluralOnly ? "pluralOnly" : nil,
                plural: pluralOnly ? nil : plural
            ))
        }
        // A word's closed-class reading first, a preposition before the
        // rest: the dictionary files its lexemes by part of speech, nouns
        // before conjunctions, so "dhe" would read "earth" before "and",
        // and "në" a conjunction before "in".
        let rank = { (entry: DictionaryFile.Entry) in closedClasses.firstIndex(of: entry.partOfSpeech) ?? closedClasses.count }
        return entries.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
    }

    private static let closedClasses = ["preposition", "pronoun", "numeral", "conjunction", "particle", "interjection", "article"]

    /// An inflection class as a noun's facts need it: its nominative
    /// indefinite plural, if it gives one, and whether all its forms are
    /// plural.
    private struct InflectionClass {
        var plural: Ending?
        var isPluralOnly: Bool
    }

    /// An ending: the stem it is added to, by number, and what follows it.
    private struct Ending {
        let stem: Int
        let suffix: String

        /// "<0>." — stem 0 bare; "<1>.e" — stem 1 and "e".
        init?(_ text: String) {
            guard text.hasPrefix("<"), let close = text.firstIndex(of: ">"),
                  let stem = Int(text[text.index(after: text.startIndex)..<close])
            else { return nil }
            self.stem = stem
            suffix = text[text.index(after: close)...].replacingOccurrences(of: ".", with: "")
        }

        func form(from stems: [String]) -> String? {
            guard stems.indices.contains(stem), !stems[stem].isEmpty else { return nil }
            return stems[stem] + suffix
        }
    }

    private static func inflectionClasses(_ lines: some Sequence<String>) -> [String: InflectionClass] {
        var classes: [String: InflectionClass] = [:]
        var name: String?
        var ending: String?
        var tagSets: [Set<String>] = []
        func close() {
            guard let name else { return }
            classes[name, default: InflectionClass(plural: nil, isPluralOnly: true)].isPluralOnly = !tagSets.isEmpty && tagSets.allSatisfy { $0.contains("pl") }
        }
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("-paradigm:") {
                close()
                name = String(text.dropFirst("-paradigm:".count)).trimmingCharacters(in: .whitespaces)
                tagSets = []
            } else if text.hasPrefix("-flex:") {
                ending = String(text.dropFirst("-flex:".count)).trimmingCharacters(in: .whitespaces)
            } else if text.hasPrefix("gramm:"), let name {
                let tags = Set(text.dropFirst("gramm:".count).trimmingCharacters(in: .whitespaces).split(separator: ",").map(String.init))
                tagSets.append(tags)
                if tags == ["pl", "nom", "indef"], classes[name]?.plural == nil, let ending, let parsed = Ending(ending) {
                    classes[name, default: InflectionClass(plural: nil, isPluralOnly: true)].plural = parsed
                }
            }
        }
        close()
        return classes
    }

    /// The blocks of a uniparser-morph file, each a field's values by its
    /// name ("lex", "stem", "paradigm" — several of one name kept in order).
    private static func blocks(_ lines: some Sequence<String>, marker: String) -> [[String: [String]]] {
        var blocks: [[String: [String]]] = []
        var current: [String: [String]]?
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text == marker {
                if let current { blocks.append(current) }
                current = [:]
            } else if current != nil, let colon = text.firstIndex(of: ":") {
                let key = String(text[..<colon])
                let value = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                current?[key, default: []].append(value)
            }
        }
        if let current { blocks.append(current) }
        return blocks
    }

    /// The dictionary's parts of speech as the app names them; a verbal
    /// particle, a form word and a clitic pronoun are left out or folded:
    /// a clitic is a pronoun.
    private static let partsOfSpeech: [String: String] = [
        "NOUN": "noun", "A": "adjective", "V": "verb", "ADV": "adverb",
        "PRO": "pronoun", "CLIT_PRO": "pronoun", "NUM": "numeral", "CONJ": "conjunction",
        "PR": "preposition", "PART": "particle", "INTJ": "interjection", "ART": "article",
    ]

    /// "mf" — a noun masculine in the singular and feminine in the plural
    /// ("mal", "male") — is written masculine: a card holds the singular.
    private static let genders: [String: String] = [
        "m": "masculine", "f": "feminine", "n": "neuter", "mf": "masculine",
    ]
}
