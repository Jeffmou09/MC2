//
//  History.swift
//  MC2
//
//  Created by Jefferson Mourent on 28/05/24.
//

import SwiftUI
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
                            NavigationLink(destination: DetailHistory(item: item)) {
                                HStack{
                                    
                                    
                                    VStack{
                                        Text(item.score)
                                            .fontWeight(.bold)
                                            .font(.system(size: 28))
                                        Text(item.date, formatter: dateFormatter)
                                            .fontWeight(.thin)
                                            .foregroundColor(.gray)
                                    }
                                }
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
