//
//  History.swift
//  MC2
//
//  Created by Jefferson Mourent on 28/05/24.
//

import SwiftUI
import AVKit
import SwiftData

struct History: View {
    @Binding var url: URL?
    @State private var selectedURL: URL?
    @Environment(\.modelContext) private var context
    @Query private var items: [DataItem]
    
    var body: some View {
        NavigationView {
            VStack{
                List{
                    ForEach(items) { item in
                        HStack{
                            Text(item.score)
                            Text("\(item.percentage)%") 
                            Text(item.date, formatter: dateFormatter)
                            if item.url != nil {
                                VideoPlayer(player: AVPlayer(url: (item.url ?? nil)!))
                                    .frame(width: 200, height: 100)
                            }
                        }
                    }
                    .onDelete { indexes in
                        for index in indexes {
                            deleteItem(items[index])
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    func deleteItem(_ item:DataItem) {
        context.delete(item)
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
