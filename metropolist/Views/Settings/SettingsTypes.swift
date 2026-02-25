import Foundation

struct TransitStats {
    let totalLines: Int
    let totalStations: Int
    let totalBranches: Int
    let linesByMode: [(mode: TransitMode, count: Int)]
    let generatedAt: String?
    let databaseSize: String?
}

struct ImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
