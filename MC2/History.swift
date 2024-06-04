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
                                    DonutChart(percentage: Double(item.percentage))
                                        .frame(width: 50, height: 50)
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.score)
                                            .fontWeight(.bold)
                                            .font(.system(size: 28))
                                        Text(item.date, formatter: dateFormatter)
                                            .fontWeight(.thin)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 8)
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
        formatter.dateFormat = "dd MMM yyyy, h.mm a"
        return formatter
    }
    
    func deleteItem(_ item:DataItem) {
        context.delete(item)
    }
}

struct DonutChart: View {
    var percentage: Double
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 1.0)
                .stroke(Color.gray.opacity(0.3), lineWidth: 7)
                .rotationEffect(Angle(degrees: -90))
            
            Circle()
                .trim(from: 0.0, to: percentage / 100)
                .stroke(colorForPercentage(percentage), lineWidth: 7)
                .rotationEffect(Angle(degrees: -90))
            
            Text("\(Int(percentage))%")
                .fontWeight(.bold)
        }
    }
    
    private func colorForPercentage(_ percentage: Double) -> Color {
        switch percentage {
        case ..<25:
            return .red
        case 25..<75:
            return .yellow
        case 75...:
            return .green
        default:
            return .gray
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
