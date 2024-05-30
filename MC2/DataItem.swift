//
//  DataItem.swift
//  MC2
//
//  Created by Jefferson Mourent on 30/05/24.
//

import Foundation
import SwiftData

@Model
class DataItem: Identifiable {
    var id: UUID
    var score: String
    var percentage: Int
    var date: Date
    var url: URL?
    
    init(score: String, percentage: Int, date: Date, url: URL? = nil) {
        self.id = UUID()
        self.score = score
        self.percentage = percentage
        self.date = date
        self.url = url
    }
    
    convenience init(score: String) {
        self.init(score: score, percentage: 0, date: Date(), url: nil)
    }
}
