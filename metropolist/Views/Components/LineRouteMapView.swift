import MapKit
import SwiftUI

struct LineRouteMapView: View {
    let segments: [[CLLocationCoordinate2D]]
    let stationAnnotations: [StationAnnotation]
    let lineColor: Color
    var preferredMapStyle: String = "standard"

    struct StationAnnotation: Identifiable, Equatable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let isTerminus: Bool

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && lhs.coordinate.latitude == rhs.coordinate.latitude
                && lhs.coordinate.longitude == rhs.coordinate.longitude
                && lhs.isTerminus == rhs.isTerminus
        }
    }

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position, interactionModes: []) {
            ForEach(segments.indices, id: \.self) { index in
                MapPolyline(coordinates: segments[index])
                    .stroke(lineColor, lineWidth: 3)
            }

            ForEach(stationAnnotations) { station in
                Annotation("", coordinate: station.coordinate) {
                    Circle()
                        .fill(.white)
                        .stroke(lineColor, lineWidth: 2)
                        .frame(width: station.isTerminus ? 10 : 6, height: station.isTerminus ? 10 : 6)
                }
            }
        }
        .mapStyle(preferredMapStyle == "satellite" ? .imagery : preferredMapStyle == "hybrid" ? .hybrid : .standard)
        .allowsHitTesting(false)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: stationAnnotations) {
            updatePosition()
        }
        .onAppear {
            updatePosition()
        }
    }

    private func updatePosition() {
        let allCoords = stationAnnotations.map(\.coordinate)
        guard !allCoords.isEmpty else {
            position = .automatic
            return
        }

        var minLat = allCoords[0].latitude
        var maxLat = allCoords[0].latitude
        var minLon = allCoords[0].longitude
        var maxLon = allCoords[0].longitude

        for coord in allCoords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
