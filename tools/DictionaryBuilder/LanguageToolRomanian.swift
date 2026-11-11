import Foundation

/// **LanguageTool's Romanian dictionary** (`romanian.dict` in
/// languagetool-org/languagetool, by Ionuț Păduraru, archeus.ro; LGPL),
/// written out by `Tools/MorfologikDump`: every word form a line — the
/// form, its base form, its tag ("Sfp3anc000"). The tag's first letter is
/// the part of speech; a noun's next ones its gender (m, f, n), number
/// (s, p), person, case ("a" the direct case), definiteness ("n"
/// indefinite) and kind ("c" common, "p" a name).
///
/// It supplements the English Wiktionary's Romanian, which describes more
/// words and every phrase: a word of its own comes in only where the
/// English edition lacks the word, so its stray readings ("repede" a
/// noun) of words already there never do.
///
/// **The LGPL asks the changed file's source to go with it**: this
/// reading, `Tools/MorfologikDump`, `DictionaryFile` and the dictionary
/// are published with the Ukrainian dictionary's source (`Vesum`), which
/// "Acknowledgements → LanguageTool" names; a change to any of them goes
/// there before the app carrying it reaches anyone.
enum LanguageToolRomanian {
    static let name = "languagetool-ro"
    static let source = "LanguageTool's Romanian dictionary (github.com/languagetool-org/languagetool), by Ionuț Păduraru"
    static let licence = "LGPL 2.1 or later"

    /// The base forms the lines describe, each reading once, in the order
    /// they first come — a noun with its gender (one only: a base form
    /// read with two gets none), plural only when it has only plural
    /// forms, its plural the direct indefinite plural form; another part
    /// of speech bare. A name and a tag naming no part of speech are left
    /// out.
    static func entries(_ lines: some Sequence<String>) -> [DictionaryFile.Entry] {
        var order: [String] = []
        var readings: [String: [String]] = [:]
        var genders: [String: Set<String>] = [:]
        var plurals: [String: String] = [:]
        var singular = Set<String>()
        for line in lines {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3, !fields[1].isEmpty else { continue }
            let (form, base, tag) = (fields[0], fields[1], Array(fields[2]))
            guard let first = tag.first, var partOfSpeech = partsOfSpeech[first] else { continue }
            // A "P" with a gender is the possessive article ("al", "a", "ale").
            if first == "P", tag.count > 1, tag[1] != "0" { partOfSpeech = "article" }
            if partOfSpeech == "noun" {
                guard tag.count >= 7, tag[6] != "p" else { continue }
                genders[base, default: []].formUnion(genderNames[tag[1]].map { [$0] } ?? [])
                if tag[2] == "s" { singular.insert(base) }
                if tag[2] == "p", tag[4] == "a", tag[5] == "n", plurals[base] == nil { plurals[base] = form }
            }
            if readings[base] == nil { order.append(base) }
            if !(readings[base]?.contains(partOfSpeech) ?? false) { readings[base, default: []].append(partOfSpeech) }
        }
        return order.flatMap { base in
            (readings[base] ?? []).map { partOfSpeech in
                guard partOfSpeech == "noun" else {
                    return DictionaryFile.Entry(word: base, partOfSpeech: partOfSpeech, gender: nil, number: nil, plural: nil)
                }
                let gender = genders[base].flatMap { $0.count == 1 ? $0.first : nil }
                let pluralOnly = !singular.contains(base) && plurals[base] != nil
                return DictionaryFile.Entry(
                    word: base, partOfSpeech: "noun", gender: gender,
                    number: pluralOnly ? "pluralOnly" : nil,
                    plural: pluralOnly ? nil : plurals[base]
                )
            }
        }
    }

    /// The tags' parts of speech as the app names them: "N" is a pronoun
    /// ("eu", "el"), "D" a determiner ("acel") — a pronoun, as the
    /// editions read one — and "P" a preposition ("între", "pe"), or with
    /// a gender the possessive article.
    private static let partsOfSpeech: [Character: String] = [
        "S": "noun", "V": "verb", "A": "adjective", "G": "adverb",
        "N": "pronoun", "D": "pronoun", "P": "preposition", "M": "numeral",
        "C": "conjunction", "I": "interjection",
    ]

    private static let genderNames: [Character: String] = [
        "m": "masculine", "f": "feminine", "n": "neuter",
    ]
}
