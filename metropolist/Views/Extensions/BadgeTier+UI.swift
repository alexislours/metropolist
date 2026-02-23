import SwiftUI

extension BadgeTier {
    var color: Color {
        switch self {
        case .locked: .gray.opacity(0.4)
        case .bronze: Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: Color(red: 0.75, green: 0.75, blue: 0.78)
        case .gold: Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }
}
