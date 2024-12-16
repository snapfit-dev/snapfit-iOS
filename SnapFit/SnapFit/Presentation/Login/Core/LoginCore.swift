//
//  LoginCore.swift
//  SnapFit
//
//  Created by 정선아 on 12/16/24.
//

import Foundation
import ComposableArchitecture
import Combine
import _AuthenticationServices_SwiftUI

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
        var cancellables = Set<AnyCancellable>()
    }

    enum Action {
        case loginWithKakao
        case loginWithApple(request: ASAuthorizationAppleIDRequest)
        case completeAppleLogin(result: Result<ASAuthorization, Error>)
        case registerUser(request: Login.LoadLogin.Request)
        case saveTokens(tokens: Tokens)
        case presentSocialLoginSuccess(socialLoginType: String, accessToken: String, oauthToken: String?)
        case presentKakaoLoginFailure(_ loginState: Bool, accessToken: String)
        case presentSocialLoginFailure(_ error: Error, socialLoginType: String, accessToken: String)
        case presentAlreadyregisteredusers(socialLoginType: String, oauthToken: String?, error: Error?)
        case presentSocialregisterSuccess(socialLoginType: String, accessToken: String, oauthToken: String?)
        case presentSocialregisterFailure(_ error: Error, socialLoginType: String, accessToken: String, oauthToken: String?)
        case display
        case fetchVibes
        case setNickname(nickname: String)
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
                                    send(.saveTokens(tokens: tokens))
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
                return .run { send in
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
                                    send(.saveTokens(tokens: tokens))
                                    send(.presentSocialLoginSuccess(socialLoginType: "apple", accessToken: accessToken, oauthToken: nil))
                                })
                                .store(in: &state.cancellables)

                        case .failure(let error):
                            send(.presentSocialLoginFailure(error, socialLoginType: "apple", accessToken: "애플로그인 실패"))
                        }
                    }
                }

            case .registerUser(request: let request):
                return .run { send in
                    authWorker.registerUser(request: request)
                                .sink(receiveCompletion: { completion in
                                    switch completion {
                                    case .failure(let error):
                                        send(.presentSocialregisterFailure(error, socialLoginType: request.social, accessToken: request.socialAccessToken, oauthToken: nil))
                                    case .finished:
                                        break
                                    }
                                }, receiveValue: { tokens in
                                    send(.saveTokens(tokens: tokens))
                                    // 옵셔널 값 처리: `accessToken`이 옵셔널이므로 `??`를 사용해 기본값을 제공
                                    let accessToken = tokens.accessToken ?? ""
                                    send(.presentSocialregisterSuccess(socialLoginType: request.social, accessToken: accessToken, oauthToken: nil))
                                })
                                .store(in: &state.cancellables)
                }

            case .saveTokens(tokens: let tokens):
                // 옵셔널 값 처리: `accessToken`과 `refreshToken`이 옵셔널이므로 기본값을 제공
                        let accessToken = tokens.accessToken ?? ""
                        let refreshToken = tokens.refreshToken ?? ""

                        UserDefaults.standard.set(accessToken, forKey: "accessToken")
                        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")

                return .none

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


            case .fetchVibes:
                return .run { send in
                    authWorker.fetchVibes()
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                print("Error fetching vibes: \(error)")
                            case .finished:
                                break
                            }
                        }, receiveValue: { vibes in
                            state.vibes = vibes
                        })
                        .store(in: &state.cancellables)
                }

            case .setNickname(nickname: let nickname):
                state.nickName = nickname
            }
        }
    }
}
