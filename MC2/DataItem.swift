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
    var duration: Int
    
    init(id: UUID = UUID(), score: String, percentage: Int, date: Date, url: URL? = nil, duration: Int = 0) {
        self.id = id
        self.score = score
        self.percentage = percentage
        self.date = date
        self.url = url
        self.duration = duration
    }
    
    convenience init(score: String) {
        self.init(score: score, percentage: 0, date: Date(), url: nil, duration: 0)
    }
}
