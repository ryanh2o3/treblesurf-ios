//
//  SurfQuality.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 04/05/2025.
//

// SurfQuality.swift
import Foundation

struct SurfQuality {
    let stars: Int // 1-5
    let description: String
    
    init(stars: Int, description: String) {
        // Ensure stars is between 1 and 5
        self.stars = min(5, max(1, stars))
        self.description = description
    }
}
