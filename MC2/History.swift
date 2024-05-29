//
//  History.swift
//  MC2
//
//  Created by Jefferson Mourent on 28/05/24.
//

import SwiftUI
import AVKit

struct History: View {
    @Binding var url: URL?
    
    var body: some View {
        NavigationView {
            VStack{
                if let url = url {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 300)
                }
                
                List{
                    HStack{
                        Image("basketmerah")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }
                    HStack{
                        Image("basketkuning")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }
                    HStack{
                        Image("basketijo")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }

                }
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    struct HistoryPreview: View {
        @State private var url: URL? = URL(string: "https://www.example.com")!
        var body: some View {
            History(url: $url)
        }
    }
    return HistoryPreview()
}
