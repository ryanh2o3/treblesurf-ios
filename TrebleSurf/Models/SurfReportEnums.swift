import Foundation

// MARK: - Surf Report Enums

enum WaveSize: String, CaseIterable {
    case flat = "flat"
    case kneeWaist = "knee-waist"
    case chestShoulder = "chest-shoulder"
    case headHigh = "head-high"
    case overhead = "overhead"
    case doubleOverhead = "double-overhead"
    
    var displayName: String {
        switch self {
        case .flat: return "Flat"
        case .kneeWaist: return "Knee-Waist"
        case .chestShoulder: return "Chest-Shoulder"
        case .headHigh: return "Head High"
        case .overhead: return "Overhead"
        case .doubleOverhead: return "Double Overhead"
        }
    }
}

enum Quality: String, CaseIterable {
    case mushy = "mushy"
    case average = "average"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .mushy: return "Mushy"
        case .average: return "Average"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}
