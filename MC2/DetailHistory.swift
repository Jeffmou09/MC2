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
    @Query private var items: [DataItem]

    var hours : Int {
        item.duration / 3600
    }
    var minutes: Int {
        (item.duration % 3600) / 60
    }
    var seconds: Int {
        item.duration % 60
    }
    
    var body: some View {
        VStack{
            if let videoURL = item.url {
                HStack{
                    Text("Date :")
                        .fontWeight(.bold)
                    Text(item.date, formatter: dateFormatter)
                    Text("Score :")
                        .fontWeight(.bold)
                    Text(item.score)
                    Text("Duration :")
                        .fontWeight(.bold)
                    Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                        
                }
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
            } else {
                Text("No video available")
                    .padding()
            }
        }
        .navigationTitle("Detail History")
        .padding()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, h.mm a"
        return formatter
    }
}

