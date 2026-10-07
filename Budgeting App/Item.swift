//
//  Item.swift
//  Budgeting App
//
//  Created by Mark Sauer on 12/09/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
