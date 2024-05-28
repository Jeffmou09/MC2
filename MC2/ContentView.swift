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
                NavigationStack {
                    ZStack {
                        HostedViewController(viewController: $viewController)
                            .ignoresSafeArea()
                        CameraView(viewController: $viewController)
                    }
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
    @State private var alert = false
    
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
                    Spacer()
                    VStack{
                        Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                            .font(.system(size: 35))
                            .foregroundStyle(Color.white)
                            .padding(.top)
                        
                        Spacer()
                       
                        if isRunning == true {
                            Text("\(madeShot) / \(attemptShot)")
                                .font(.system(size: 170))
                                .padding(.bottom, 50)
                                .opacity(0.5)
                        }
                        
                        Spacer()
                    }
                    Spacer()
                }
                HStack{
                    Spacer()
                    VStack{
                        if isRunning == false {
                            Button(action: {
                                viewController?.switchCamera()
                            }, label: {
                                Image("balik")
                            })
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if isRunning == false {
                                startTimer()
                            } else {
                                resetTimer()
                                alert = true
                            }
                        }, label: {
                            ZStack {
                                if isRunning == false {
                                    Circle()
                                        .tint(.red)
                                        .frame(width: 62, height: 62)
                                } else {
                                    Rectangle()
                                        .tint(.red)
                                        .frame(width: 37, height: 37)
                                        .cornerRadius(3.0)
                                }
                                Circle()
                                    .stroke(.white, lineWidth: 5)
                                    .frame(width: 75, height: 75)
                                    .padding(.bottom, 2)
                            }
                        })
                        
                        Spacer()
                        if isRunning == false {
                            NavigationLink(destination: History()) {
                                Image("history")
                            }
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .background(.clear)
            .alert(isPresented: $alert) {
                Alert(
                    title: Text("Your Score"),
                    message: Text("\(madeShot) / \(attemptShot)"),
                    dismissButton: .default(Text("OK"))
                )
            
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
    CameraView(viewController: .constant(ViewController()))
}
