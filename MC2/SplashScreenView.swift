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
                .foregroundColor(.black)
                .ignoresSafeArea()
            
            Image(systemName: "basketball.fill")
                .foregroundColor(.white)
                .font(.system(size: 100))
        }
    }
}

#Preview {
    SplashScreenView()
}
