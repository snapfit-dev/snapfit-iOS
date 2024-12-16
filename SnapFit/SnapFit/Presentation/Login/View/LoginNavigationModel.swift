//
//  TermsView.swift
//  SnapFit
//
//  Created by SnapFit on 11/23/24.
//

import SwiftUI

class LoginNavigationModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    
    func append(_ value: String) {
        navigationPath.append(value)
    }
    
    func pop() {
        navigationPath.removeLast()
    }
    
    func resetNavigation() {
        navigationPath.removeLast(navigationPath.count)
    }
}
