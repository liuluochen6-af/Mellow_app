import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showPhoneLogin = false
    @State private var appleNonce: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 60))
                        .foregroundColor(.black)

                    Text("Mellow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text("记录你的探索足迹")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    #if APPLE_SIGN_IN_ENABLED
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        appleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleLogin(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(25)
                    #endif

                    Button {
                        showPhoneLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("手机号登录")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)

                if let error = authService.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.bottom)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(isPresented: $showPhoneLogin) {
                PhoneLoginView()
            }
        }
    }

    private func handleAppleLogin(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCodeData = credential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                  let nonce = appleNonce else {
                authService.errorMessage = "Apple 登录凭证不完整，请重试"
                return
            }
            let fullName = credential.fullName
            let nickname = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                await authService.appleLogin(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: nonce,
                    nickname: nickname
                )
            }
        case .failure:
            authService.errorMessage = "Apple 登录已取消"
        }
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                fatalError("Unable to generate a secure nonce")
            }
            if Int(random) < characters.count {
                result.append(characters[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }
}
