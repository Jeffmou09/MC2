//
//  Record.swift
//  MC2
//
//  Created by Jefferson Mourent on 29/05/24.
//

import SwiftUI
import ReplayKit

extension View {
    
    func startRecording(enableMic: Bool = false, completion: @escaping (Error?)->()) {
        let recorder = RPScreenRecorder.shared()
        
        recorder.isMicrophoneEnabled = false
        
        recorder.startRecording(handler: completion)
    }
    
    func stopRecording() async throws->URL {
        let name = UUID().uuidString + ".mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        
        let recorder = RPScreenRecorder.shared()
        
        try await recorder.stopRecording(withOutput: url)
        
        print(url)
        
        return url
    }
}
