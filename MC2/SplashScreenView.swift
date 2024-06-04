//
//  SplashScreenView.swift
//  MC2
//
//  Created by Jefferson Mourent on 22/05/24.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.white)
                .ignoresSafeArea()
            
            Image("HoopScore")
                .resizable()
                .frame(width: 250, height: 250)
        }
    }
}

#Preview {
    SplashScreenView()
}
