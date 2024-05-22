//
//  Timer.swift
//  MC2
//
//  Created by Jefferson Mourent on 21/05/24.
//

import SwiftUI

struct StopWatch: View {
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
        VStack {
            Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                .font(.system(size: 50))
            
            HStack {
                Button(action: {
                    if !isRunning {
                        startTimer()
                    } else {
                        stopTimer()
                    }
                }) {
                    Text(isRunning ? "Stop" : "Start")
                }
                
                Button(action: resetTimer) {
                    Text("Reset")
                }
            }
            .padding()
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
    StopWatch()
}
