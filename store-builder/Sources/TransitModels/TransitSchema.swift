import Foundation
import SwiftData

public enum TransitSchema {
    public static let version = 1

    public static let models: [any PersistentModel.Type] = [
        TransitLine.self,
        TransitStation.self,
        TransitRouteVariant.self,
        TransitLineStop.self,
        TransitTransfer.self,
        TransitMetadata.self,
    ]

    public enum MetadataKey {
        public static let generatedAt = "generatedAt"
        public static let dataVersion = "dataVersion"
        public static let schemaVersion = "schemaVersion"
    }

    public static let tableNames = [
        "ZTRANSITLINE",
        "ZTRANSITSTATION",
        "ZTRANSITROUTEVARIANT",
        "ZTRANSITLINESTOP",
        "ZTRANSITTRANSFER",
        "ZTRANSITMETADATA",
    ]
}
