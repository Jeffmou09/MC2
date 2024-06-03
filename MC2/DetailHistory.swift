//
//  DetailHistory.swift
//  MC2
//
//  Created by Jefferson Mourent on 31/05/24.
//

import SwiftUI
import SwiftData
import AVKit

struct DetailHistory: View {
    let item: DataItem

    var body: some View {
        VStack{
            if let videoURL = item.url {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
            } else {
                Text("No video available")
                    .padding()
            }
            
            Text(item.date, formatter: dateFormatter)
        }
        .navigationTitle("Detail History")
        .padding()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

