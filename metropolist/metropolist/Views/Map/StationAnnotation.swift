import MapKit
import SwiftUI

// MARK: - Station Selection

struct MapStationSelection: Equatable {
    let sourceID: String
    let name: String
}

// MARK: - Annotation Model

final class StationAnnotation: NSObject, MKAnnotation {
    let identifier: String
    let coordinate: CLLocationCoordinate2D
    let pointCount: Int
    let isVisited: Bool
    let visitedRatio: Double
    let stationName: String

    var title: String? {
        pointCount > 1 ? "\(pointCount)" : stationName
    }

    init(cluster: MapCluster, visitedStationIDs: Set<String>) {
        identifier = cluster.id
        coordinate = cluster.coordinate
        pointCount = cluster.pointCount
        stationName = cluster.name
        if cluster.pointCount == 1 {
            isVisited = cluster.stationSourceID.map { visitedStationIDs.contains($0) } ?? false
            visitedRatio = isVisited ? 1 : 0
        } else {
            let visitedCount = cluster.sourceIDs.count { visitedStationIDs.contains($0) }
            visitedRatio = Double(visitedCount) / Double(max(cluster.sourceIDs.count, 1))
            isVisited = visitedRatio == 1
        }
    }
}
