import Foundation
import SQLite3

struct DatabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// SQLite is included in iOS. No third-party database framework or server credentials.
final class Database {
    private var connection: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
            .appendingPathComponent("FindMyToilet", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("find-my-toilet.sqlite")
    }
    init(url: URL) throws {
        guard sqlite3_open(url.path, &connection) == SQLITE_OK else {
            let error = failure()
            sqlite3_close(connection)
            connection = nil
            throw error
        }
        do {
            try execute("PRAGMA foreign_keys = ON;")
            try execute("PRAGMA journal_mode = DELETE;")
            try execute("PRAGMA secure_delete = ON;")
            let version = try strings("PRAGMA user_version;").first ?? "0"
            guard version == "0" || version == "1" else {
                throw DatabaseError(message: "Базата е от по-нова версия на приложението. Данните не са променени.")
            }
            try execute("""
                CREATE TABLE IF NOT EXISTS toilets (
                    id TEXT PRIMARY KEY NOT NULL,
                    payload BLOB NOT NULL
                );
                CREATE TABLE IF NOT EXISTS reviews (
                    id TEXT PRIMARY KEY NOT NULL,
                    toilet_id TEXT NOT NULL UNIQUE REFERENCES toilets(id),
                    payload BLOB NOT NULL
                );
                CREATE TABLE IF NOT EXISTS favorites (
                    toilet_id TEXT PRIMARY KEY NOT NULL REFERENCES toilets(id)
                );
                CREATE TABLE IF NOT EXISTS reports (
                    id TEXT PRIMARY KEY NOT NULL,
                    toilet_id TEXT NOT NULL REFERENCES toilets(id),
                    payload BLOB NOT NULL
                );
                CREATE INDEX IF NOT EXISTS reports_toilet_idx ON reports(toilet_id);
                PRAGMA user_version = 1;
                """)
            try transaction {
                for toilet in DemoData.toilets {
                    try insert("INSERT OR IGNORE INTO toilets (id,payload) VALUES (?,?);",
                               texts: [toilet.id], payload: JSONEncoder().encode(toilet))
                }
            }
        } catch {
            sqlite3_close(connection)
            connection = nil
            throw error
        }
    }
    deinit { sqlite3_close(connection) }

    func toilets() throws -> [Toilet] { try objects("SELECT payload FROM toilets ORDER BY id;", as: Toilet.self) }
    func load() throws -> LocalData {
        LocalData(reviews: try objects("SELECT payload FROM reviews;", as: Review.self),
                  reports: try objects("SELECT payload FROM reports;", as: IssueReport.self),
                  favoriteIDs: Set(try strings("SELECT toilet_id FROM favorites;")))
    }
    // The small local prototype writes a snapshot in one transaction. A failed write rolls back fully.
    func save(_ data: LocalData) throws {
        try transaction {
            try execute("DELETE FROM reviews; DELETE FROM reports; DELETE FROM favorites;")
            for review in data.reviews {
                try insert("INSERT INTO reviews (id,toilet_id,payload) VALUES (?,?,?);",
                           texts: [review.id.uuidString, review.toiletID], payload: JSONEncoder().encode(review))
            }
            for report in data.reports {
                try insert("INSERT INTO reports (id,toilet_id,payload) VALUES (?,?,?);",
                           texts: [report.id.uuidString, report.toiletID], payload: JSONEncoder().encode(report))
            }
            for id in data.favoriteIDs {
                try insert("INSERT INTO favorites (toilet_id) VALUES (?);", texts: [id], payload: nil)
            }
        }
    }
    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do { try work(); try execute("COMMIT;") }
        catch { try? execute("ROLLBACK;"); throw error }
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        return statement
    }
    private func insert(_ sql: String, texts: [String], payload: Data?) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for (offset, text) in texts.enumerated() {
            let code = text.withCString { sqlite3_bind_text(statement, Int32(offset + 1), $0, -1, transient) }
            guard code == SQLITE_OK else { throw failure() }
        }
        if let payload {
            let code = payload.withUnsafeBytes {
                sqlite3_bind_blob(statement, Int32(texts.count + 1), $0.baseAddress, Int32($0.count), transient)
            }
            guard code == SQLITE_OK else { throw failure() }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }
    private func objects<T: Decodable>(_ sql: String, as type: T.Type) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var result: [T] = []
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { throw DatabaseError(message: "Невалиден запис в базата.") }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            result.append(try JSONDecoder().decode(type, from: data))
            code = sqlite3_step(statement)
        }
        guard code == SQLITE_DONE else { throw failure() }
        return result
    }
    private func strings(_ sql: String) throws -> [String] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var result: [String] = []
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 0) { result.append(String(cString: text)) }
            code = sqlite3_step(statement)
        }
        guard code == SQLITE_DONE else { throw failure() }
        return result
    }
    private func failure() -> DatabaseError {
        DatabaseError(message: "Грешка в локалната база: \(connection.map { String(cString: sqlite3_errmsg($0)) } ?? "не може да бъде отворена")")
    }
}
