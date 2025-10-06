//
//  Item.swift
//  MovApp
//
//  Created by Akinalp Fidan on 6.10.2025.
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
