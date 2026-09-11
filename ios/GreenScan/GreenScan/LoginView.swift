import SwiftUI

/// PM이 공유한 로그인 화면 레퍼런스 이미지 포팅(2026-09-11). 웹 LoginPage.tsx는
/// 스타일이 하나도 안 입혀진 상태였는데, 이 레퍼런스가 실제 디자인 의도라
/// 여기 기준으로 새로 짰다. 소셜 로그인 3종(카카오/네이버/구글)은 버튼만 —
/// 실제 OAuth 연동은 아직 없다.
///
/// 아이디/비밀번호 로그인은 데모용으로 admin1234 / 1234만 통과한다
/// (AuthState.demoLoginId/demoPassword, PM 지시 2026-09-11).
struct LoginView: View {
    @Environment(AuthState.self) private var auth

    @State private var loginId = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case id, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("로그인")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 90)
                    .padding(.bottom, 48)

                VStack(spacing: 12) {
                    field("아이디", text: $loginId)
                        .focused($focusedField, equals: .id)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                    field("비밀번호", text: $password, secure: true)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                }
                .padding(.horizontal, 24)

                if let error = auth.loginError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                Button(action: submit) {
                    Group {
                        if auth.isLoggingIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("로그인")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brand500)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                }
                .disabled(auth.isLoggingIn || loginId.isEmpty || password.isEmpty)
                .opacity(auth.isLoggingIn || loginId.isEmpty || password.isEmpty ? 0.6 : 1)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                // 데모 힌트 — 실서버 연동 후에도 남겨둔다: 와이파이가 불안정할 때만
                // 오프라인 폴백으로 쓰이는 안전장치라, 발표 중 참고용으로 필요하다.
                .overlay(alignment: .bottom) {
                    Text("실서버 계정 또는 오프라인 데모: admin1234 / 1234")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .offset(y: 20)
                }

                HStack(spacing: 12) {
                    Text("비밀번호 찾기")
                    Divider().frame(height: 12)
                    Text("아이디 찾기")
                    Divider().frame(height: 12)
                    Text("회원가입")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

                Divider().padding(.top, 24).padding(.horizontal, 24)

                VStack(spacing: 12) {
                    socialButton(title: "카카오로 계속하기", background: Color(hex: "FEE500"), foreground: .black.opacity(0.85)) {
                        Image(systemName: "bubble.fill")
                    }
                    socialButton(title: "네이버로 계속하기", background: Color(hex: "03C75A"), foreground: .white) {
                        Text("N").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                    }
                    socialButton(title: "구글로 계속하기", background: Color(.systemBackground), foreground: .black, bordered: true) {
                        Text("G").font(.system(size: 16, weight: .heavy)).foregroundStyle(Color(hex: "4285F4"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                HStack(spacing: 12) {
                    Text("고객센터")
                    Divider().frame(height: 12)
                    Text("개인정보처리방침")
                    Divider().frame(height: 12)
                    Text("이용약관")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 60)
                .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }

    private func submit() {
        focusedField = nil
        Task { await auth.login(loginId: loginId, password: password) }
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(hex: "F2F2F2"))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func socialButton<Icon: View>(
        title: String,
        background: Color,
        foreground: Color,
        bordered: Bool = false,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button {
            // 소셜 로그인은 아직 실제 OAuth 연동 전이라 데모 계정으로 바로 통과시킨다.
            Task { await auth.login(loginId: AuthState.demoLoginId, password: AuthState.demoPassword) }
        } label: {
            HStack {
                icon().frame(width: 20)
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .foregroundStyle(foreground)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(bordered ? Color(hex: "E0E0E0") : .clear, lineWidth: 1)
        )
    }
}

#Preview {
    LoginView().environment(AuthState())
}
