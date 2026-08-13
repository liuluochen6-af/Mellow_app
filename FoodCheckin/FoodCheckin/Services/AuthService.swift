import Foundation
import UIKit
import AuthenticationServices

struct SendCodeBody: Encodable {
    let phone: String
}

struct PhoneLoginBody: Encodable {
    let phone: String
    let code: String
}

struct AppleLoginBody: Encodable {
    let identity_token: String
    let authorization_code: String
    let nonce: String
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

    @Published var devCode: String?

    func sendCode(phone: String) async -> Bool {
        errorMessage = nil
        devCode = nil
        do {
            let body = SendCodeBody(phone: phone)
            let data = try await APIClient.shared.post("/api/auth/send-code", body: body)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["dev_code"] as? String {
                devCode = code
            }
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

    func appleLogin(
        identityToken: String,
        authorizationCode: String,
        nonce: String,
        nickname: String
    ) async {
        errorMessage = nil
        guard APIClient.shared.isSecureTransport else {
            errorMessage = "Apple 登录需要服务器启用 HTTPS"
            return
        }
        do {
            let body = AppleLoginBody(
                identity_token: identityToken,
                authorization_code: authorizationCode,
                nonce: nonce,
                nickname: nickname
            )
            let data = try await APIClient.shared.post("/api/auth/apple-login", body: body)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            KeychainHelper.save(token: response.token)
            currentUser = response.user
            isLoggedIn = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Apple 登录失败，请重试"
        }
    }

    func logout() {
        KeychainHelper.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }

    func loadProfile() async {
        guard KeychainHelper.getToken() != nil else { return }
        do {
            let data = try await APIClient.shared.get("/api/auth/me")
            let user = try JSONDecoder().decode(UserProfile.self, from: data)
            currentUser = user
        } catch {}
    }

    func updateProfile(nickname: String?, avatar: UIImage?) async -> Bool {
        do {
            let data = try await APIClient.shared.uploadProfile(nickname: nickname, avatarData: avatar?.jpegData(compressionQuality: 0.7))
            let decoder = JSONDecoder()
            let user = try decoder.decode(UserProfile.self, from: data)
            currentUser = user
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "保存失败，请重试"
            return false
        }
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
