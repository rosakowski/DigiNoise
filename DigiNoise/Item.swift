//
//  Item.swift
//  DigiNoise
//
//  Created by Ross Sakowski on 2/3/26.
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
