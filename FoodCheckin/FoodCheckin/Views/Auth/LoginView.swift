import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showPhoneLogin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 60))
                        .foregroundColor(.black)

                    Text("吃喝玩乐打卡")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text("记录你的探索足迹")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        handleAppleLogin(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(25)

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
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userID = credential.user
            let fullName = credential.fullName
            let nickname = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                await authService.appleLogin(appleID: userID, nickname: nickname)
            }
        case .failure:
            authService.errorMessage = "Apple 登录已取消"
        }
    }
}
