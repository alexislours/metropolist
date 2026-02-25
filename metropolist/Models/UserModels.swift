import Foundation
import SwiftData

enum FavoriteKind: String {
    case line
    case station
}

@Model
final class Favorite {
    var id: String = ""
    var kind: String = ""
    var sourceID: String = ""
    var createdAt: Date = Date()

    init(kind: String, sourceID: String) {
        id = "\(kind):\(sourceID)"
        self.kind = kind
        self.sourceID = sourceID
        createdAt = Date()
    }
}

@Model
final class CompletedStop {
    var id: String = "" // "{lineSourceID}:{stationSourceID}"
    var lineSourceID: String = ""
    var stationSourceID: String = ""
    var completedAt: Date = Date()
    var travelID: String?

    init(lineSourceID: String, stationSourceID: String, travelID: String? = nil) {
        id = "\(lineSourceID):\(stationSourceID)"
        self.lineSourceID = lineSourceID
        self.stationSourceID = stationSourceID
        completedAt = Date()
        self.travelID = travelID
    }
}

@Model
final class Travel {
    var id: String = "" // UUID string
    var lineSourceID: String = ""
    var routeVariantSourceID: String = ""
    var fromStationSourceID: String = ""
    var toStationSourceID: String = ""
    var stopsCompleted: Int = 0
    var createdAt: Date = Date()

    init(
        lineSourceID: String,
        routeVariantSourceID: String,
        fromStationSourceID: String,
        toStationSourceID: String,
        stopsCompleted: Int
    ) {
        id = UUID().uuidString
        self.lineSourceID = lineSourceID
        self.routeVariantSourceID = routeVariantSourceID
        self.fromStationSourceID = fromStationSourceID
        self.toStationSourceID = toStationSourceID
        self.stopsCompleted = stopsCompleted
        createdAt = Date()
    }
}
