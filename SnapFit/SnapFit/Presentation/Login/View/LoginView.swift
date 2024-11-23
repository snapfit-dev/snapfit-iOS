//
//  LoginDisplayLogic.swift
//  SnapFit
//
//  Created by SnapFit on 11/22/24.
//


import SwiftUI
import _AuthenticationServices_SwiftUI
import ComposableArchitecture
import Combine

@Reducer
struct LoginCore {
    @ObservableState
    struct State {
        var isKakaoLogin = false
        var isAppleLoggedIn = false
        var shouldNavigate: Bool = false
        var appleUserIdentifier: String? = nil
        var loginMessage: String = ""

        var social: String = ""
        var nickName: String = ""
        var isMarketing: Bool = false
        var oauthToken: String = ""
        var moods: [String] = []
        var socialAccessToken: String = ""
        // Add this property
        var vibes: [Vibe] = []
        var showLoginModal: Bool = true
        var model: Login.LoadLogin.LoginPresentationViewModel
        var navigationStack: LoginNavigationModel
    }

    enum Action {
        case loginWithKakao
        case loginWithApple(request: ASAuthorizationAppleIDRequest)
        case completeAppleLogin(result: Result<ASAuthorization, Error>)
        case registerUser(request: Login.LoadLogin.Request)
        case fetchVibes
        case saveTokens(_ tokens: Tokens)
        case presentSocialLoginSuccess(socialLoginType: String, accessToken: String, oauthToken: String?)
        case presentKakaoLoginFailure(_ loginState: Bool, accessToken: String)
        case presentSocialLoginFailure(_ error: Error, socialLoginType: String, accessToken: String)
        case presentAlreadyregisteredusers(socialLoginType: String, oauthToken: String?, error: Error?)
        case presentSocialregisterSuccess(socialLoginType: String, accessToken: String, oauthToken: String?)
        case presentSocialregisterFailure(_ error: Error, socialLoginType: String, accessToken: String, oauthToken: String?)
        case presentVibes(_ vibes: [Vibe])
        case presentVibesFetchFailure(_ error: Error)
        case display
    }

    private let authWorker: AuthWorkingLogic
    private var cancellables = Set<AnyCancellable>()

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .loginWithKakao:
                return .run { send in
                    authWorker.loginWithKakao { [weak self] result in
                        switch result {
                        case .success(let accessToken):
                            self?.authWorker.socialLoginSnapfitServer(accessToken: accessToken, socialType: "kakao")
                                .sink(receiveCompletion: { completion in
                                    switch completion {
                                    case .failure(let error):
                                        send(.presentSocialLoginFailure(error, socialLoginType: "kakao", accessToken: accessToken)) // 존재하지 않으면 기존 애플, 카카오 엑세스 토큰 전달 뷰 모델로 -> 회원가입 로직
                                    case .finished:
                                        break
                                    }
                                }, receiveValue: { tokens in //유저가 존재하면 토큰값 저장 후 메인뷰 전환
                                    // 1. 토큰을 저장
                                    send(.saveTokens(tokens))
                                    send(.presentSocialLoginSuccess(socialLoginType: "kakao", accessToken: accessToken, oauthToken: nil))
                                })
                                .store(in: &self!.cancellables)

                        case .failure(let error):
                            send(.presentKakaoLoginFailure(false, accessToken: ""))
                        }
                    }
                }

            case .loginWithApple(request: let request):
                authWorker.initiateAppleLogin(request: request)

                return .none

            case .completeAppleLogin(result: let result):
                authWorker.completeAppleLogin(result: result) { [weak self] result in
                    switch result {
                    case .success(let accessToken):
                        self?.authWorker.socialLoginSnapfitServer(accessToken: accessToken, socialType : "apple")
                            .sink(receiveCompletion: { completion in
                                switch completion {
                                case .failure(let error): // 실패시 애플에서 받은 엑세스 토큰을 저장
                                    send(.presentSocialLoginFailure(error, socialLoginType: "apple", accessToken: accessToken))
                                case .finished:
                                    break
                                }
                            }, receiveValue: { tokens in
                                // 1. 애플 로그인 성공시 스냅핏 토큰을 저장
                                send(.saveTokens(tokens))
                                send(.presentSocialLoginSuccess(socialLoginType: "apple", accessToken: accessToken, oauthToken: nil))
                            })
                            .store(in: &self!.cancellables)

                    case .failure(let error):
                        send(.presentSocialLoginFailure(error, socialLoginType: "apple", accessToken: "애플로그인 실패"))
                    }
                }

                return .none

            case .registerUser(request: let request):
                <#code#>
            case .fetchVibes:
                <#code#>
            case .saveTokens(_):
                <#code#>

            case .presentSocialLoginSuccess(socialLoginType: let socialLoginType,
                                            accessToken: let accessToken,
                                            oauthToken: let oauthToken):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: socialLoginType,
                                                                         oauthToken: oauthToken,
                                                                         socialAccessToken: accessToken,
                                                                         membershipRequired: false)

                return .send(.display)

            case .presentKakaoLoginFailure(_,
                                           accessToken: let accessToken):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: "kakao",
                                                                         oauthToken: accessToken,
                                                                         socialAccessToken: nil,
                                                                         membershipRequired: false)

                return .send(.display)

            case .presentSocialLoginFailure(_,
                                            socialLoginType: let socialLoginType,
                                            accessToken: let accessToken):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: socialLoginType,
                                                                         oauthToken: "",
                                                                         socialAccessToken: accessToken,
                                                                         membershipRequired: true)

                return .send(.display)

            case .presentAlreadyregisteredusers(socialLoginType: let socialLoginType,
                                                oauthToken: let oauthToken,
                                                error: let error):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: socialLoginType,
                                                                         oauthToken: oauthToken,
                                                                         socialAccessToken: nil,
                                                                         membershipRequired: false)

                return .send(.display)

            case .presentSocialregisterSuccess(socialLoginType: let socialLoginType,
                                               accessToken: let accessToken,
                                               oauthToken: let oauthToken):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: socialLoginType,
                                                                         oauthToken: oauthToken,
                                                                         socialAccessToken: accessToken,
                                                                         membershipRequired: false)

                return .send(.display)

            case .presentSocialregisterFailure(_,
                                               socialLoginType: let socialLoginType,
                                               accessToken: let accessToken,
                                               oauthToken: let oauthToken):
                state.model = Login.LoadLogin.LoginPresentationViewModel(socialLoginType: socialLoginType,
                                                                         oauthToken: oauthToken,
                                                                         socialAccessToken: accessToken,
                                                                         membershipRequired: true)

                return .send(.display)

            case .presentVibes(_):
                <#code#>
            case .presentVibesFetchFailure(_):
                <#code#>
            case .display:
                return .run { send in
                    var destination = ""
                    print("viewModel.membershipRequired \(state.model.membershipRequired)")
                    if state.model.membershipRequired == true {
                        destination = "termsView"
                        state.navigationStack.navigationPath.append(destination)
                    } else {
                        state.showLoginModal = false
                    }
                    switch state.model.socialLoginType {
                    case "kakao":
                        if state.model.membershipRequired {
                            state.isKakaoLogin = true
                            print("Kakao login failed verification kakaoAccessToken \(state.socialAccessToken ?? "")")
                        } else {
                            print("Kakao login successful")
                            state.showLoginModal = false
                        }
                    case "apple":
                        if state.model.membershipRequired {
                            state.isAppleLoggedIn = true
                            print("Apple login failed verification \(state.oauthToken ?? "")")
                        } else {
                            print("Apple login successful")
                            state.showLoginModal = false
                        }
                    default:
                        print("Unsupported social login type")
                    }
                }
            }
        }
    }
}

// View가 Presenter로부터 받는 정보를 정의하는 프로토콜
protocol LoginDisplayLogic {
    func displayVibes(viewModel: Login.LoadLogin.VibesPresentationViewModel)
}

// 로그인 화면을 정의하는 View
struct LoginView: View, LoginDisplayLogic {
    
    // 모달로 올라오면 뷰모델 끊어짐, 스택도 끊어지고
    @Binding var store: StoreOf<LoginCore>

    func displayVibes(viewModel: Login.LoadLogin.VibesPresentationViewModel) {
        DispatchQueue.main.async {
            self.loginviewModel.vibes = viewModel.vibes
        }
    }

    var body: some View {
        NavigationStack(path: store.state.navigationStack.navigationPath) {
            GeometryReader { geometry in
                ZStack {
                    Image("LoginBack")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                    
                    VStack(alignment: .leading) {
                        Spacer().frame(height: geometry.size.height * 0.14)
                        
                        Group {
                            Image("appLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 155, height: 63)
                                .padding(.bottom, 24)
                            
                            Text("당신의 아름다운 순간을 담다.")
                                .font(.callout)
                                .foregroundColor(Color("LoginFontColor"))
                        }
                        .font(.title3)
                        
                        Spacer()
                        
                        LoginViewGroup(interactor: interactor, viewModel: loginviewModel)
                        
                        Spacer().frame(height: geometry.size.height * 0.03)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "termsView":
                    TermsView(navigationPath: navigationModel, viewModel: loginviewModel, interactor: interactor)
                        .navigationBarBackButtonHidden(true)
                case "NicknameSettingsView":
                    NicknameSettingsView(navigationPath: navigationModel, viewModel: loginviewModel, interactor: interactor)
                        .navigationBarBackButtonHidden(true)
                case "GridSelectionView":
                    GridSelectionView(columnsCount: 2, viewModel: loginviewModel, navigationPath: navigationModel, interactor: interactor)
                        .navigationBarBackButtonHidden(true)
                case "FreelookView":
                    FreelookView() // FreelookView를 네비게이션 링크로 표시
                        .navigationBarBackButtonHidden(true)
                default:
                    EmptyView()
                }
            }
            .navigationBarBackButtonHidden(true)
            .ignoresSafeArea()
        }
    }
}


// 로그인 버튼 및 로그인 관련 UI를 정의하는 구조체
private struct LoginViewGroup: View {
    @Binding var store: StoreOf<LoginCore>

    var body: some View {
        VStack(spacing: 20) {
            Image("LoginDscription")
                .resizable()
                .scaledToFill()
                .frame(width: 178, height: 12)
                .overlay {
                    HStack {
                        Image("LoginDscriptionLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 10, height: 10)
                        
                        Text("3초만에 빠른 로그인")
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                    .offset(y: -7)
                }
            
            Button {
                interactor?.loginWithKakao()
            } label: {
                HStack(spacing: 70) {
                    Image("kakaoButton")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .padding(.leading)
                    
                    Text("카카오로 계속하기")
                        .font(.system(size: 15))
                        .bold()
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding()
                .background(Color.yellow)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 50)
            .cornerRadius(10)
            
            SignInWithAppleButton(
                onRequest: { request in interactor?.loginWithApple(request: request) },
                onCompletion: { result in interactor?.completeAppleLogin(result: result) }
            )
            .overlay {
                HStack(spacing: 70) {
                    Image("AppleButton")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .padding(.leading)
                    
                    Text("Apple로 계속하기")
                        .font(.system(size: 15))
                        .bold()
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .allowsHitTesting(false)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 50)
            .cornerRadius(10)
            
            NavigationLink(value: "FreelookView") {
                Text("둘러보기")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.7))
                    .underline()
            }
            .padding(.bottom, 20)
        }
    }
}


//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginView(loginviewModel: LoginViewModel(), navigationModel: LoginNavigationModel())
//            .environmentObject(LoginNavigationModel())  // Preview를 위한 네비게이션 모델 제공
//    }
//}
