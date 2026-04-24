//
//  SplashView.swift
//  VibeTrip
//
//  Created by CHOI on 4/24/26.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            Image("Splash_Logo")
        }
    }
}

#Preview {
    SplashView()
}
