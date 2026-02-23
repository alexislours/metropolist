import Foundation

enum TransitMode: String, CaseIterable {
    case metro
    case rer
    case train
    case tram
    case bus
    case cableway
    case funicular
    case regionalRail
    case railShuttle

    var label: String {
        switch self {
        case .metro: String(localized: "Metro", comment: "Transit mode: metro/subway")
        case .rer: String(localized: "RER", comment: "Transit mode: RER regional express")
        case .train: String(localized: "Train", comment: "Transit mode: train")
        case .tram: String(localized: "Tram", comment: "Transit mode: tram/streetcar")
        case .bus: String(localized: "Bus", comment: "Transit mode: bus")
        case .cableway: String(localized: "Cable Car", comment: "Transit mode: cable car")
        case .funicular: String(localized: "Funicular", comment: "Transit mode: funicular railway")
        case .regionalRail: String(localized: "Regional Rail", comment: "Transit mode: regional rail")
        case .railShuttle: String(localized: "Shuttle", comment: "Transit mode: rail shuttle")
        }
    }

    var systemImage: String {
        switch self {
        case .metro: "tram.fill"
        case .rer: "train.side.front.car"
        case .train: "train.side.front.car"
        case .tram: "tram"
        case .bus: "bus.fill"
        case .cableway: "cablecar.fill"
        case .funicular: "cablecar"
        case .regionalRail: "train.side.front.car"
        case .railShuttle: "train.side.rear.car"
        }
    }

    var sortOrder: Int {
        switch self {
        case .metro: 0
        case .rer: 1
        case .train: 2
        case .tram: 3
        case .bus: 4
        case .cableway: 5
        case .funicular: 6
        case .regionalRail: 7
        case .railShuttle: 8
        }
    }
}
