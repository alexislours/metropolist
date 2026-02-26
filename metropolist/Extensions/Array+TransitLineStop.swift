import TransitModels

extension [TransitLineStop] {
    /// Returns the stop order for the first occurrence of `stationSourceID`.
    func order(of stationSourceID: String) -> Int? {
        first(where: { $0.stationSourceID == stationSourceID })?.order
    }

    /// Returns the minimum stop order for `stationSourceID` that is after `minOrder`.
    func order(of stationSourceID: String, after minOrder: Int) -> Int? {
        var best: Int?
        for stop in self where stop.stationSourceID == stationSourceID && stop.order > minOrder {
            if let current = best {
                if stop.order < current { best = stop.order }
            } else {
                best = stop.order
            }
        }
        return best
    }

    /// Returns the maximum stop order for `stationSourceID` that is before `maxOrder`.
    func order(of stationSourceID: String, before maxOrder: Int) -> Int? {
        var best: Int?
        for stop in self where stop.stationSourceID == stationSourceID && stop.order < maxOrder {
            if let current = best {
                if stop.order > current { best = stop.order }
            } else {
                best = stop.order
            }
        }
        return best
    }
}
