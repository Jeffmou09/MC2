//
//  ContentView.swift
//  MC2
//
//  Created by Jefferson Mourent on 17/05/24.
//

import CoreML
import SwiftUI

struct ContentView: View {
    @State private var viewController: ViewController?
    @State private var showSplash = true
    
    var body: some View {
        ZStack{
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                ZStack {
                    HostedViewController(viewController: $viewController)
                        .ignoresSafeArea()
                    
                    CameraView(viewController: $viewController)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.showSplash = false
                }
            }
        }
    }
}

struct CameraView: View {
    @Binding var viewController: ViewController?
    
    @State private var madeShot = 0
    @State private var attemptShot = 0
    @State private var progressTime = 0
    @State private var isRunning = false
    
    var hours : Int {
        progressTime / 3600
    }
    var minutes: Int {
        (progressTime % 3600) / 60
    }
    var seconds: Int {
        progressTime % 60
    }
    
    @State private var timer: Timer?
    
    var body: some View {
        ZStack{
            HStack{
                VStack{
                    Button(action: {
                        
                    }, label: {
                        Image("history")
                    })
                    Spacer()
                }
                .padding(.top, 40)
                
                Spacer()
                VStack{
                    Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                        .font(.system(size: 50))
                        .padding(.top)
                    
                    Spacer()
                   
                }
                Spacer()
            }
            HStack{
                Spacer()
                VStack{
                    Button(action: {
                        viewController?.switchCamera()
                    }, label: {
                        Image("balik")
                    })
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    Button(action: {
                        if !isRunning {
                            startTimer()
                        } else {
                            resetTimer()
                        }
                    }, label: {
                        ZStack {
                            Circle()
                                .tint(.white)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .stroke(.white)
                                .frame(width: 65, height: 65)
                        }
                    })
                    .padding(.bottom, 60)
                    
                    Spacer()
                    
                }
            }
        }
    }
    
    func startTimer() {
           isRunning = true
           timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
               progressTime += 1
           }
       }
       
       func stopTimer() {
           isRunning = false
           timer?.invalidate()
           timer = nil
       }
       
       func resetTimer() {
           progressTime = 0
           stopTimer()
       }
}

#Preview {
    ContentView()
}
