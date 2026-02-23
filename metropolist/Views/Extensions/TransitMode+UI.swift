import SwiftUI

extension TransitMode {
    var tintColor: Color {
        switch self {
        case .metro: .purple
        case .rer: .blue
        case .train: .indigo
        case .tram: .teal
        case .bus: .orange
        case .cableway: .cyan
        case .funicular: .mint
        case .regionalRail: .indigo
        case .railShuttle: .gray
        }
    }
}
