import Foundation

struct CloudError: LocalizedError {
    let message: String
    let status: Int?
    let code: String?
    init(_ message: String, status: Int? = nil, code: String? = nil) {
        self.message = message; self.status = status; self.code = code
    }
    var errorDescription: String? { message }
    static func serverResponse(status: Int, data: Data) -> CloudError {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = body?["error_code"] as? String ?? body?["code"] as? String
        func failure(_ message: String) -> CloudError { CloudError(message, status: status, code: code) }
        switch code {
        case "invalid_credentials":
            return failure("Невалиден имейл или парола. Проверете данните си за вход.")
        case "otp_expired":
            return failure("Кодът е невалиден или изтекъл. Поискайте нов и използвайте най-новия имейл.")
        case "email_not_confirmed":
            return failure("Потвърдете имейла си чрез връзката от Supabase, след което влезте отново.")
        default: break
        }
        if status == 401 { return failure("Сесията е изтекла или данните за вход са грешни. Влезте отново.") }
        if status == 403 { return failure("Нямате права за това действие.") }
        if status == 429 { return failure("Твърде много заявки. Изчакайте и опитайте отново.") }
        return failure(body?["msg"] as? String ?? body?["message"] as? String ?? body?["error_description"] as? String ?? "Грешка от сървъра (\(status)).")
    }

}

