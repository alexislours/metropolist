import Foundation
import TransitModels

extension DataStore {
    static func makeTransitUpdateModel(descriptor: TransitStoreDescriptor) -> TransitUpdateModel {
        guard let root = try? transitSupportRoot() else {
            return TransitUpdateModel(
                service: TransitUpdateService(root: FileManager.default.temporaryDirectory),
                installedDataVersion: descriptor.dataVersion
            )
        }
        return TransitUpdateModel(descriptor: descriptor, root: root)
    }
}
