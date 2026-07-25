import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var countdown = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Text("手机号登录")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.black)

            VStack(spacing: 16) {
                TextField("手机号", text: $phone)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)

                if codeSent {
                    HStack {
                        TextField("验证码", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)

                        Button(countdown > 0 ? "\(countdown)s" : "重发") {
                            sendCode()
                        }
                        .disabled(countdown > 0)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(countdown > 0 ? Color.gray.opacity(0.3) : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button {
                if codeSent {
                    login()
                } else {
                    sendCode()
                }
            } label: {
                Text(codeSent ? "登录" : "获取验证码")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(phone.count >= 11 ? Color.black : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .disabled(phone.count < 11)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 40)
        .background(Color.white.ignoresSafeArea())
        .onDisappear { timer?.invalidate() }
    }

    private func sendCode() {
        Task {
            let success = await authService.sendCode(phone: phone)
            if success {
                codeSent = true
                startCountdown()
                if let devCode = authService.devCode {
                    code = devCode
                }
            }
        }
    }

    private func login() {
        Task {
            await authService.phoneLogin(phone: phone, code: code)
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}
