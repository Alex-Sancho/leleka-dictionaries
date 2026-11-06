// Each row holds part of speech, gender, number and plural, each
// small-lettered for lookups. `meta` holds format, language, edition,
// extract date, revision, source and licence. The revision (`revision`)
// is what the builder made of the extract – 3 once each closed class is a
// class of its own. Also writing a new file.

import Foundation
import SQLite3

/// **A dictionary file — the one place that knows its shape**, for the
/// builder that writes it (`Tools/DictionaryBuilder` compiles this file
/// too) and the app that reads it (`FileDictionary`).
///
/// SQLite, read-only on the device: one row per word with its part of
/// speech and, for a noun, gender, number and plural, by the names the
/// app's rules use ("noun", "feminine", "pluralOnly"); each word and
/// plural also small-lettered for a lookup that ignores letter case;
/// what the file is in `meta` — its format, language, edition, the
/// extract's date, its revision, the source and its licence.
public enum DictionaryFile {
    /// Changes when the shape does; a file of another format is not read.
    public static let format = 1

    /// **What the builder made of an extract** — changes when the same
    /// extract would become a different file (2: a preposition kept apart
    /// from "other word"; 3: each closed class — pronoun, numeral,
    /// conjunction, interjection, article — a class of its own), so a file
    /// on a device of the same edition and extract is known for an older
    /// one and replaced (`DictionaryShelf.isCurrent`). A file or an entry
    /// with none is the first.
    public static let revision = 3

    /// One word as the file keeps it.
    public struct Entry: Hashable, Sendable {
        public let word: String
        public let partOfSpeech: String
        public let gender: String?
        public let number: String?
        public let plural: String?

        public init(word: String, partOfSpeech: String, gender: String?, number: String?, plural: String?) {
            self.word = word
            self.partOfSpeech = partOfSpeech
            self.gender = gender
            self.number = number
            self.plural = plural
        }
    }

    static let schema = """
        create table meta(key text primary key, value text);
        create table word(word text not null, key text not null, part text not null, gender text, number text, plural text, plural_key text);
        create index word_key on word(key);
        create index word_plural on word(plural_key);
        """

    /// The small-lettered form a lookup goes by.
    static func key(_ text: String) -> String {
        text.lowercased()
    }

    /// Writes a new file — the builder's; one already there is replaced.
    public static func write(_ entries: [Entry], to path: String, meta: [String: String]) throws {
        try? FileManager.default.removeItem(atPath: path)
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK, let db else { throw Failure("cannot open \(path)") }
        defer { sqlite3_close(db) }
        try run(db, "begin; " + schema)
        try insert(db, "insert into meta values(?, ?)", rows: meta.sorted { $0.key < $1.key }.map { [$0.key, $0.value] })
        try insert(db, "insert into word values(?, ?, ?, ?, ?, ?, ?)", rows: entries.map {
            [$0.word, key($0.word), $0.partOfSpeech, $0.gender, $0.number, $0.plural, $0.plural.map(key)]
        })
        try run(db, "commit; vacuum;")
    }

    private static func run(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw Failure(String(cString: sqlite3_errmsg(db))) }
    }

    private static func insert(_ db: OpaquePointer, _ sql: String, rows: [[String?]]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw Failure(String(cString: sqlite3_errmsg(db))) }
        defer { sqlite3_finalize(statement) }
        for row in rows {
            for (index, value) in row.enumerated() {
                if let value {
                    sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient)
                } else {
                    sqlite3_bind_null(statement, Int32(index + 1))
                }
            }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw Failure(String(cString: sqlite3_errmsg(db))) }
            sqlite3_reset(statement)
        }
    }

    /// SQLite copies a bound text at once.
    static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
