//
//  ContentView.swift
//  MC2
//
//  Created by Jefferson Mourent on 17/05/24.
//

import CoreML
import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var context
    @Query private var items: [DataItem]
    
    @Binding var viewController: ViewController?
    
    @State private var madeShot = 0
    // toggleScore prevent multiple score made on ball on the rim
    @State private var toggleAttempt: Bool = true
    @State private var toggleScore: Bool = true
    @State private var attemptShot = 0
    @State private var progressTime = 0
    @State private var durasi = 0
    @State private var alert = false
    @State private var isRecording: Bool = false
    @State var url: URL?
    
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
                    
                    if isRecording == true {
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
                    if isRecording == false {
                        Button(action: {
                            viewController?.switchCamera()
                        }, label: {
                            Image("balik")
                        })
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        
                    }, label: {
                        ZStack {
                            Button(action: {
                                if isRecording{
                                    Task {
                                        do{
                                            self.url = try await stopRecording()
                                            print(self.url ?? "")
                                            isRecording = false
                                            resetTimer()
                                            addItem()
                                            attemptShot = 0
                                            madeShot = 0
                                        }
                                        catch{
                                            print(error.localizedDescription)
                                        }
                                    }
                                } else {
//                                    startRecording {error in
//                                        if let error = error {
//                                            print(error.localizedDescription)
//                                            return
//                                        }
//                                        
//                                        isRecording = true
//                                    }
                                    addAttempt()
                                    startTimer()
                                }
                            }, label: {
                                if !isRecording{
                                    Circle()
                                        .tint(.red)
                                        .frame(width: 62, height: 62)
                                } else {
                                    Rectangle()
                                        .tint(.red)
                                        .frame(width: 37, height: 37)
                                        .cornerRadius(3.0)
                                }
                            })
                            
                            Circle()
                                .stroke(.white, lineWidth: 5)
                                .frame(width: 75, height: 75)
                                .padding(.bottom, 2)
                        }
                    })
                    
                    Spacer()
                    if isRecording == false {
                        NavigationLink(destination: History(url: $url)) {
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
        .onChange(of: viewController, { oldValue, newValue in
            viewController?.increaseScore = { [self] in
                if !isRecording {
                    return
                }
                if toggleScore {
                    madeShot += 1
                    toggleScore = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        toggleScore = true
                    }
                }
            }
//            viewController?.increaseAttempt = { [self] in
//                if isRecording {
//                    attemptShot += 1
//                }
//            }
        })
        .onAppear {
            durasi = 0
        }
    }
    
    func addAttempt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            attemptShot += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
            attemptShot += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 28) {
            attemptShot += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 38) {
            attemptShot += 1
        }
    }
    
    func startTimer() {
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            progressTime += 1
        }
    }
    
    func stopTimer() {
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        durasi = progressTime
        progressTime = 0
        stopTimer()
    }
    
    func addItem() {
        // Pastikan attemptShot tidak nol untuk menghindari pembagian dengan nol
        let percentage = attemptShot > 0 ? (madeShot * 100 / attemptShot) : 0
        let item = DataItem(score: "\(madeShot) / \(attemptShot)", percentage: percentage, date: Date(), url: url, duration: durasi)
        context.insert(item)
    }
}

#Preview {
    CameraView(viewController: .constant(ViewController()))
}
