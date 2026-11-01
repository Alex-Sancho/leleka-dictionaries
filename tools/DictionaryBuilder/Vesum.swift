import Foundation

/// **VESUM, the large electronic dictionary of Ukrainian** (brown-uk,
/// github.com/brown-uk/dict_uk), as its LanguageTool package carries it
/// (`morfologik-ukrainian-lt`, LGPL 2.1 or later), written out by
/// `Tools/MorfologikDump`: every word form a line — the form, its base
/// form, its tags ("noun:inanim:f:v_naz"). The tags are the package's
/// `tagset.txt`.
///
/// Ukrainian's words are read here rather than from a Wiktionary
/// edition: kaikki.org reads no Ukrainian edition, and the English one
/// describes 13 thousand Ukrainian nouns where VESUM describes them all.
enum Vesum {
    static let name = "vesum"
    static let source = "VESUM (github.com/brown-uk/dict_uk), through its LanguageTool package morfologik-ukrainian-lt"
    static let licence = "LGPL 2.1 or later"

    /// The base forms the lines describe — a noun with its gender (one
    /// only: "сирота", masculine and feminine, gets none), its number when
    /// it has one only ("ns" — no singular, "np" — no plural) and its
    /// plural, the nominative plural — none where two are equally common
    /// ("гра": "гри", "ігри"), rather than the wrong one; another part of
    /// speech bare. A form marked "bad" (a calque), "alt" (spelling outside
    /// the current rules) or a name ("prop") is left out; a plural "rare"
    /// or archaic only if no other is there.
    static func entries(_ lines: some Sequence<String>) -> [DictionaryFile.Entry] {
        var nouns = Set<String>()
        var genders: [String: Set<String>] = [:]
        var numbers: [String: String] = [:]
        var plurals: [String: (forms: [String], plain: Bool)] = [:]
        var others: [String: Set<String>] = [:]
        var order: [String] = []
        var seen = Set<String>()

        for line in lines {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 3 else { continue }
            let form = String(fields[0]), lemma = String(fields[1])
            let tags = fields[2].split(separator: ":").map(String.init)
            guard let part = tags.first, !tags.contains(where: { left.contains($0) }) else { continue }
            if seen.insert(lemma).inserted { order.append(lemma) }

            if part == "noun", !tags.contains("pron") {
                guard tags.contains("v_naz") else { continue }
                let plain = !tags.contains(where: { uncommon.contains($0) })
                if form == lemma, let gender = tags.compactMap({ genderNames[$0] }).first {
                    nouns.insert(lemma)
                    genders[lemma, default: []].insert(gender)
                    if tags.contains("np") { numbers[lemma] = "singularOnly" }
                } else if form == lemma, tags.contains("p"), tags.contains("ns") {
                    nouns.insert(lemma)
                    numbers[lemma] = "pluralOnly"
                } else if tags.contains("p") {
                    // A plain form replaces uncommon ones; one as common
                    // as those kept joins them.
                    if let kept = plurals[lemma], kept.plain || !plain {
                        if kept.plain == plain, !kept.forms.contains(form) { plurals[lemma] = (kept.forms + [form], plain) }
                    } else {
                        plurals[lemma] = ([form], plain)
                    }
                }
            } else if form == lemma, let partOfSpeech = baseForm(part, tags) {
                others[lemma, default: []].insert(partOfSpeech)
            }
        }

        var entries: [DictionaryFile.Entry] = []
        for lemma in order {
            if nouns.contains(lemma) {
                let number = numbers[lemma]
                let found = genders[lemma] ?? []
                entries.append(DictionaryFile.Entry(
                    word: lemma,
                    partOfSpeech: "noun",
                    gender: number != "pluralOnly" && found.count == 1 ? found.first : nil,
                    number: number,
                    plural: number == nil ? plurals[lemma].flatMap { $0.forms.count == 1 ? $0.forms[0] : nil } : nil
                ))
            }
            for partOfSpeech in (others[lemma] ?? []).sorted() {
                entries.append(DictionaryFile.Entry(word: lemma, partOfSpeech: partOfSpeech, gender: nil, number: nil, plural: nil))
            }
        }
        return entries
    }

    /// A base form's part of speech as the app names it: a verb's
    /// infinitive, an adjective's (a participle's too) masculine
    /// nominative, the uninflected parts as they are; a pronoun ("pron") and
    /// the rest — "other word". `nil` — not a base form.
    private static func baseForm(_ part: String, _ tags: [String]) -> String? {
        if tags.contains("pron") { return tags.contains("v_naz") || part != "noun" && part != "adj" ? "otherWord" : nil }
        switch part {
        case "verb": return tags.contains("inf") ? "verb" : nil
        case "adj": return tags.contains("m") && tags.contains("v_naz") ? "adjective" : nil
        case "adv": return "adverb"
        case "part": return "particle"
        case "prep", "conj", "intj", "numr", "noninfl": return "otherWord"
        default: return nil
        }
    }

    /// Tags whose form is left out: a calque, a spelling outside the
    /// current rules, a name, an abbreviation.
    private static let left: Set<String> = ["bad", "alt", "prop", "abbr"]
    /// Tags of a form kept only when no other is there.
    private static let uncommon: Set<String> = ["rare", "arch", "obsc", "coll", "slang", "subst"]
    private static let genderNames: [String: String] = ["m": "masculine", "f": "feminine", "n": "neuter"]
}
