import SwiftUI
import ComposableArchitecture

struct GridSelectionView: View {
    @Binding var store: StoreOf<LoginCore>
    @State private var isConfirmButtonEnabled = false
    @State private var selectedItems: Set<Int> = []
    @State private var showAlert = false
    
    let columnsCount: Int
    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6, alignment: nil), count: columnsCount)
    }
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading) {
            
            Group {
                Text("어느 분위기의\n사진 촬영을 원하시나요?")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)
                    .padding(.top, 50)
                
                Text("최대 2개까지 선택이 가능합니다.")
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                    .padding(.bottom)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    alignment: .center,
                    spacing: 19) {
                        ForEach(store.state.vibes.indices, id: \.self) { index in
                            Button {
                                // Ensure index is within bounds of the viewModel.vibes array
                                guard index >= 0 && index < store.state.vibes.count else { return }

                                if selectedItems.contains(index) {
                                    // Deselect the item
                                    selectedItems.remove(index)
                                    if let name = store.state.vibes[index].name {
                                        DispatchQueue.main.async {
                                            store.state.moods.removeAll { $0 == name }
                                        }
                                    }
                                } else if selectedItems.count < 2 {
                                    // Select the item
                                    selectedItems.insert(index)
                                    if let name = store.state.vibes[index].name {
                                        DispatchQueue.main.async {
                                            store.state.moods.append(name)
                                        }
                                    }
                                } else {
                                    // Show alert when more than 2 items are selected
                                    showAlert = true
                                }
                                // Enable or disable confirm button based on selection count
                                DispatchQueue.main.async {
                                    isConfirmButtonEnabled = selectedItems.count > 0
                                }
                            } label: {
                                Text(store.state.vibes[index].name ?? "")
                                    .foregroundColor(selectedItems.contains(index) ? Color.white : Color.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(selectedItems.contains(index) ? Color.black : Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding()
            }
            Spacer()
            
            Button {
                // Action for "시작하기"
                DispatchQueue.main.async {
                    store.send(.registerUser(request: Login.LoadLogin.Request(
                        social: store.state.social,
                        nickName: store.state.nickName,
                        isMarketing: store.state.isMarketing,
                        oauthToken: store.state.oauthToken,
                        socialAccessToken: store.state.socialAccessToken,
                        moods: store.state.moods
                    )))

                    // 로그인 성공 시 모달 닫기
                    //viewModel.membershipRequired = false
                    store.state.showLoginModal = false
                    //navigationPath.navigationPath = .init()
                }
            } label: {
                HStack(spacing: 20) {
                    Spacer()
                    Text("시작하기")
                        .font(.callout)
                        .bold()
                        .foregroundColor(isConfirmButtonEnabled ? Color(.white) : Color(.systemGray))
                    Spacer()
                }
                .padding()
                .frame(height: 48)
                .background(isConfirmButtonEnabled ? Color(.black) : Color(.systemGray4))
                .cornerRadius(5)
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 40, trailing: 20))
            }
            .disabled(!isConfirmButtonEnabled)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                }
            }
        }
        .overlay(
            ZStack {
                if showAlert {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    CustomAlertView(isPresented: $showAlert, message: "최대 2개까지 \n선택이 가능합니다.") {
                        showAlert = false
                    }
                    .frame(width: 300)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2.5)
                }
            }
        )
        .onAppear {
            DispatchQueue.main.async {
                print("GridSelectionView appeared")
                
                // Reset selected items and moods
                selectedItems.removeAll()
                store.state.moods.removeAll()

                // Fetch vibes again if necessary
                store.send(.fetchVibes)

                // Disable the confirm button initially
                isConfirmButtonEnabled = false
            }
        }

    }
}


