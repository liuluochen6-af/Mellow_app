import Foundation
import AuthenticationServices

struct SendCodeBody: Encodable {
    let phone: String
}

struct PhoneLoginBody: Encodable {
    let phone: String
    let code: String
}

struct AppleLoginBody: Encodable {
    let apple_id: String
    let nickname: String
}

@MainActor
class AuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserProfile?
    @Published var errorMessage: String?

    init() {
        isLoggedIn = KeychainHelper.getToken() != nil
    }

    func sendCode(phone: String) async -> Bool {
        errorMessage = nil
        do {
            let body = SendCodeBody(phone: phone)
            _ = try await APIClient.shared.post("/api/auth/send-code", body: body)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "网络错误，请重试"
            return false
        }
    }

    func phoneLogin(phone: String, code: String) async {
        errorMessage = nil
        do {
            let body = PhoneLoginBody(phone: phone, code: code)
            let data = try await APIClient.shared.post("/api/auth/phone-login", body: body)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            KeychainHelper.save(token: response.token)
            currentUser = response.user
            isLoggedIn = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "登录失败，请重试"
        }
    }

    func appleLogin(appleID: String, nickname: String) async {
        errorMessage = nil
        do {
            let body = AppleLoginBody(apple_id: appleID, nickname: nickname)
            let data = try await APIClient.shared.post("/api/auth/apple-login", body: body)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            KeychainHelper.save(token: response.token)
            currentUser = response.user
            isLoggedIn = true
        } catch {
            errorMessage = "Apple 登录失败"
        }
    }

    func logout() {
        KeychainHelper.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }

    func deleteAccount() async {
        do {
            _ = try await APIClient.shared.delete("/api/auth/delete-account")
            logout()
        } catch {
            errorMessage = "删除失败"
        }
    }
}
