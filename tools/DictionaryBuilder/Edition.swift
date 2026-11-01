import Foundation

/// **How one Wiktionary edition writes a word's facts** — each edition its
/// own way, so each has its own reading. A language's words come from its
/// own edition; a language kaikki.org reads no edition of (Ukrainian)
/// takes them from the English one, which describes every language.
struct Edition {
    let name: String
    /// Where the words come from, as the acknowledgement names it.
    let source: String
    /// The word's entry, or `nil` — another language's, an inflected
    /// form, or a part of speech a card has no use for.
    let entry: (_ object: [String: Any], _ language: String) -> DictionaryFile.Entry?

    static let all: [Edition] = [german, french, spanish, english]
    static var names: [String] { all.map(\.name) }

    static func named(_ name: String) -> Edition? {
        all.first { $0.name == name }
    }

    /// **The German Wiktionary**: a noun's gender among its tags
    /// ("neuter"); its forms each with its case and number — the plural
    /// the nominative plural, a noun with only a singular form singular
    /// only ("Obst"), with only a plural one plural only ("Leute"); an
    /// inflected form an entry of its own, marked by its category or by a
    /// sense pointing to its base form.
    static let german = Edition(name: "de", source: "de.wiktionary.org, through kaikki.org") { object, language in
        guard let (word, partOfSpeech) = baseForm(object, language),
              !(object["categories"] as? [String] ?? []).contains(where: { $0.contains("Flektierte Form") })
        else { return nil }
        guard partOfSpeech == "noun" else { return other(word, partOfSpeech) }
        let forms = forms(object).filter { $0.tags.contains("nominative") && $0.form != "—" }
        let singular = forms.contains { $0.tags.contains("singular") }
        let plural = forms.first { $0.tags.contains("plural") }?.form
        let number: String? = switch (singular, plural) {
        case (true, nil): "singularOnly"
        case (false, .some): "pluralOnly"
        default: nil
        }
        return noun(word, genders: tags(object), number: number, plural: plural)
    }

    /// **The French Wiktionary**: a noun's gender among its tags, "plural
    /// only" and "singular only" there too ("gens", "plural-only"); the
    /// plural the form tagged plural alone; an inflected form an entry of
    /// its own, its sense pointing to its base form.
    static let french = Edition(name: "fr", source: "fr.wiktionary.org, through kaikki.org") { object, language in
        tagged(object, language)
    }

    /// **The Spanish Wiktionary** — written as the French one.
    static let spanish = Edition(name: "es", source: "es.wiktionary.org, through kaikki.org") { object, language in
        tagged(object, language)
    }

    /// **The English Wiktionary**, for English and for a language read
    /// from no edition of its own: a noun's gender on its headword's form
    /// ("canonical", Ukrainian "feminine"), else on its first sense; its
    /// plural the form tagged plural alone (English) or nominative plural
    /// (a language with cases), its stress marks taken off; "plural-only"
    /// among the tags; an English noun with no plural whose first sense is
    /// uncountable — singular only ("news").
    static let english = Edition(name: "en", source: "en.wiktionary.org, through kaikki.org") { object, language in
        guard let (word, partOfSpeech) = baseForm(object, language) else { return nil }
        guard partOfSpeech == "noun" else { return other(word, partOfSpeech) }
        let forms = forms(object)
        let firstSense = (object["senses"] as? [[String: Any]])?.first?["tags"] as? [String] ?? []
        let headword = forms.first { $0.tags.contains("canonical") }?.tags ?? []
        let genders = !genderTags(headword).isEmpty ? headword : !genderTags(tags(object)).isEmpty ? tags(object) : firstSense
        let plural = (forms.first { $0.tags == ["plural"] } ?? forms.first { $0.tags == ["nominative", "plural"] })
            .map { withoutStress($0.form) }
        let allTags = Set(tags(object) + headword + firstSense)
        let number: String? = allTags.contains("plural-only") ? "pluralOnly"
            : plural == nil && firstSense.contains("uncountable") && !firstSense.contains("countable") ? "singularOnly"
            : nil
        return noun(word, genders: genders, number: number, plural: plural)
    }

    // MARK: - What the editions share

    /// The French and Spanish way: gender and number among the entry's
    /// tags, the plural the form tagged plural alone.
    private static func tagged(_ object: [String: Any], _ language: String) -> DictionaryFile.Entry? {
        guard let (word, partOfSpeech) = baseForm(object, language) else { return nil }
        guard partOfSpeech == "noun" else { return other(word, partOfSpeech) }
        let tags = tags(object)
        let number: String? = tags.contains("plural-only") ? "pluralOnly" : tags.contains("singular-only") ? "singularOnly" : nil
        let plural = forms(object).first { $0.tags == ["plural"] }?.form
        return noun(word, genders: tags, number: number, plural: plural)
    }

    /// The entry's word and part of speech, if it is a base form of the
    /// language in a part of speech the app names: an inflected form
    /// ("form-of" among its tags, a sense pointing to its base form) is
    /// left out.
    private static func baseForm(_ object: [String: Any], _ language: String) -> (String, String)? {
        guard object["lang_code"] as? String == language,
              let word = object["word"] as? String, !word.isEmpty,
              let partOfSpeech = partsOfSpeech[object["pos"] as? String ?? ""],
              !tags(object).contains("form-of"),
              !(object["senses"] as? [[String: Any]] ?? []).contains(where: { $0["form_of"] != nil })
        else { return nil }
        return (word, partOfSpeech)
    }

    private static func other(_ word: String, _ partOfSpeech: String) -> DictionaryFile.Entry {
        DictionaryFile.Entry(word: word, partOfSpeech: partOfSpeech, gender: nil, number: nil, plural: nil)
    }

    /// A noun: its gender only when the tags name one; its plural only
    /// for a noun with both numbers.
    private static func noun(_ word: String, genders tags: [String], number: String?, plural: String?) -> DictionaryFile.Entry {
        let genders = genderTags(tags)
        return DictionaryFile.Entry(
            word: word,
            partOfSpeech: "noun",
            gender: genders.count == 1 ? genders[0] : nil,
            number: number,
            plural: number == nil ? plural : nil
        )
    }

    private static func tags(_ object: [String: Any]) -> [String] {
        object["tags"] as? [String] ?? []
    }

    private static func forms(_ object: [String: Any]) -> [(form: String, tags: [String])] {
        (object["forms"] as? [[String: Any]] ?? []).compactMap { form in
            guard let text = form["form"] as? String else { return nil }
            return (text, (form["tags"] as? [String] ?? []).sorted())
        }
    }

    private static func genderTags(_ tags: [String]) -> [String] {
        Array(Set(tags.compactMap { genderNames[$0] })).sorted()
    }

    /// A form as it is written: Wiktionary marks the stress of a Ukrainian
    /// word ("ві́кна"), which no card or book writes.
    private static func withoutStress(_ form: String) -> String {
        String(String.UnicodeScalarView(form.unicodeScalars.filter { $0 != "\u{0301}" }))
    }

    /// The editions' parts of speech as the app names them; a word known
    /// as another is kept as "other word", so the app knows it is none of
    /// these. Names of people and places, affixes, verb forms of their own
    /// (Spanish participles) are left out.
    private static let partsOfSpeech: [String: String] = [
        "noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb", "particle": "particle", "phrase": "phrase",
        "prep": "otherWord", "pron": "otherWord", "conj": "otherWord", "intj": "otherWord", "num": "otherWord", "article": "otherWord",
        "det": "otherWord",
    ]

    private static let genderNames: [String: String] = [
        "masculine": "masculine", "feminine": "feminine", "neuter": "neuter",
    ]
}
