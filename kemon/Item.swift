//
//  Item.swift
//  kemon
//
//  Created by Muhammad Nurul Akbar on 01/07/26.
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
