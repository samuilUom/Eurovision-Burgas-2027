import Foundation
import Security
import ImageIO
import UniformTypeIdentifiers

struct UserProfile: Codable, Identifiable {
    let id: String
    var display_name: String
    let role: String
    var avatar_base64: String?
    var avatarData: Data? { avatar_base64.flatMap { Data(base64Encoded: $0) } }
    var isAdmin: Bool { role == "admin" }
}

struct BackendConfiguration: Codable {
    let url: String
    let publicKey: String
    func validate() throws {
        guard let parts = URLComponents(string: url), parts.scheme == "https", let host = parts.host,
              !host.isEmpty, parts.user == nil, parts.password == nil, parts.query == nil,
              parts.fragment == nil, parts.path.isEmpty || parts.path == "/" else {
            throw CloudError("Въведете HTTPS Project URL от Supabase, без допълнителен път.")
        }
        if publicKey.hasPrefix("sb_publishable_") { return }
        let pieces = publicKey.split(separator: ".")
        if pieces.count == 3 {
            var value = String(pieces[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            value += String(repeating: "=", count: (4 - value.count % 4) % 4)
            if let data = Data(base64Encoded: value), let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               claims["role"] as? String == "anon" { return }
        }
        throw CloudError("Използвайте publishable или anon ключ. Secret/service-role ключове не се допускат в приложението.")
    }
    private static func fileURL() throws -> URL { try Database.defaultURL().deletingLastPathComponent().appendingPathComponent("backend.json") }
    static func load() -> BackendConfiguration? {
        if let url = try? fileURL(), let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(Self.self, from: data), (try? config.validate()) != nil {
            return config
        }
        // A publishable key is safe to distribute; authorization is enforced by server RLS.
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseProjectURL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String else { return nil }
        let config = BackendConfiguration(url: url, publicKey: key)
        return (try? config.validate()) != nil ? config : nil
    }
    func save() throws {
        try validate()
        try JSONEncoder().encode(self).write(to: Self.fileURL(), options: [.atomic, .completeFileProtection])
    }
}

enum ConfirmationCode {
    static func isValid(_ value: String) -> Bool {
        (6...10).contains(value.count) && value.utf8.allSatisfy { (48...57).contains($0) }
    }
}

struct AuthUser: Codable { let id: String; let email: String? }
private struct AuthResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Double?
    let user: AuthUser?
}
struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: AuthUser
}

enum SessionVault {
    private static func query(_ server: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "bg.findmytoilet.auth",
         kSecAttrAccount as String: server]
    }
    static func read(server: String) throws -> AuthSession? {
        var request = query(server)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CloudError("Сесията в Keychain не може да бъде прочетена.") }
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }
    static func save(_ session: AuthSession, server: String) throws {
        let data = try JSONEncoder().encode(session)
        let changes = [kSecValueData as String: data]
        let updated = SecItemUpdate(query(server) as CFDictionary, changes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw CloudError("Сесията не може да бъде запазена в Keychain.") }
        var request = query(server)
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw CloudError("Сесията не може да бъде запазена в Keychain.") }
    }
    static func clear(server: String) throws {
        let result = SecItemDelete(query(server) as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw CloudError("Изходът не успя. Опитайте отново.") }
    }
}

struct ToiletRow: Codable { let id: String; let created_by: String; let payload: Toilet }
struct ReviewRow: Codable { let id: UUID; let toilet_id: String; let author_id: String; let payload: Review }
struct FavoriteRow: Codable { let user_id: String; let toilet_id: String }
struct ReportRow: Codable { let id: UUID; let toilet_id: String; let author_id: String; let payload: IssueReport }

@MainActor
final class CloudClient {
    let configuration: BackendConfiguration
    private(set) var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?

    init(configuration: BackendConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
    }
    func restoreSession() async throws {
        let server = configuration.url
        // Keychain may wait for an OS service. Never block the UI's first frame on it.
        let restored = try await Task.detached(priority: .userInitiated) {
            try SessionVault.read(server: server)
        }.value
        try Task.checkCancellation()
        session = restored
    }
    func login(email: String, password: String) async throws {
        let data = try await request(path: "/auth/v1/token", method: "POST", query: [.init(name: "grant_type", value: "password")],
                                     body: JSONEncoder().encode(["email": email, "password": password]))
        try await accept(data)
    }
    // Email confirmation may mean signup deliberately returns no session.
    func signup(name: String, email: String, password: String) async throws -> Bool {
        struct Signup: Encodable { let email: String; let password: String; let data: [String: String] }
        let body = Signup(email: email, password: password, data: ["display_name": name])
        let data = try await request(path: "/auth/v1/signup", method: "POST", body: JSONEncoder().encode(body))
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        if response.access_token != nil { try await accept(data); return true }
        return false
    }
    func resendConfirmation(email: String) async throws {
        _ = try await request(path: "/auth/v1/resend", method: "POST",
                              body: JSONEncoder().encode(["type": "signup", "email": email]))
    }
    func confirmEmail(email: String, code: String) async throws {
        guard ConfirmationCode.isValid(code) else { throw CloudError("Въведете цифровия код от най-новия имейл.") }
        let data = try await request(path: "/auth/v1/verify", method: "POST",
                                     body: JSONEncoder().encode(["type": "email", "email": email, "token": code]))
        try await accept(data)
    }
    func logout() async throws {
        // Clear the device session even if the remote revocation request fails offline.
        if let token = session?.accessToken { _ = try? await request(path: "/auth/v1/logout", method: "POST", token: token) }
        let server = configuration.url
        try await Task.detached { try SessionVault.clear(server: server) }.value
        session = nil
        refreshTask?.cancel()
        refreshTask = nil
    }
    private func accept(_ data: Data) async throws {
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        let value = try makeSession(response)
        let server = configuration.url
        try await Task.detached { try SessionVault.save(value, server: server) }.value
        session = value
    }
    private func makeSession(_ response: AuthResponse) throws -> AuthSession {
        guard let access = response.access_token, let refresh = response.refresh_token, let user = response.user else {
            throw CloudError("Няма активна сесия. Потвърдете имейла и влезте отново.")
        }
        return AuthSession(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(response.expires_in ?? 3600), user: user)
    }
    private func token() async throws -> String? {
        guard let session else { return nil }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        let task = Task<AuthSession, Error> {
            let data = try await request(path: "/auth/v1/token", method: "POST", query: [.init(name: "grant_type", value: "refresh_token")],
                                         body: JSONEncoder().encode(["refresh_token": session.refreshToken]))
            return try makeSession(JSONDecoder().decode(AuthResponse.self, from: data))
        }
        refreshTask = task
        defer { refreshTask = nil }
        let renewed = try await task.value
        try Task.checkCancellation()
        let server = configuration.url
        try await Task.detached { try SessionVault.save(renewed, server: server) }.value
        self.session = renewed
        return renewed.accessToken
    }
    func rows<T: Decodable>(_ table: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> [T] {
        var all: [T] = []
        var offset = 0
        while true {
            let page: [T] = try await rest(table, query: query + [.init(name: "limit", value: "100"), .init(name: "offset", value: String(offset))], as: [T].self)
            all += page
            if page.count < 100 { return all }
            offset += page.count
        }
    }
    func rest<T: Decodable>(_ table: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil,
                            prefer: String? = nil, as type: T.Type) async throws -> T {
        let data = try await request(path: "/rest/v1/\(table)", method: method, query: query, body: body, token: try await token(), prefer: prefer)
        return try JSONDecoder().decode(type, from: data)
    }
    private func request(path: String, method: String, query: [URLQueryItem] = [], body: Data? = nil,
                         token: String? = nil, prefer: String? = nil) async throws -> Data {
        guard var components = URLComponents(string: configuration.url) else { throw CloudError("Невалиден адрес на сървъра.") }
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw CloudError("Невалиден адрес на заявката.") }
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.publicKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError("Сървърът не отговори.") }
        guard (200...299).contains(http.statusCode) else {
            throw CloudError.serverResponse(status: http.statusCode, data: data)
        }
        return data.isEmpty ? Data("[]".utf8) : data
    }
}

enum AvatarImage {
    static func prepare(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320
              ] as CFDictionary) else { return nil }
        let side = min(image.width, image.height)
        guard let crop = image.cropping(to: CGRect(x: (image.width-side)/2, y: (image.height-side)/2, width: side, height: side)) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, crop, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= 90000 else { return nil }
        return output as Data
    }
}
