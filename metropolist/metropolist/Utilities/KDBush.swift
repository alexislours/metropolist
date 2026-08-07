import Foundation

struct KDPoint {
    nonisolated let originalIndex: Int
    nonisolated let xCoord: Double
    nonisolated let yCoord: Double
}

private struct KDStackEntry {
    nonisolated let left: Int
    nonisolated let right: Int
    nonisolated let depth: Int
}

struct KDBush {
    nonisolated let ids: [Int]
    nonisolated let coords: [KDPoint]
    nonisolated let nodeSize: Int

    nonisolated init(points: [(Double, Double)], nodeSize: Int = 64) {
        self.nodeSize = nodeSize
        var sortable = points.enumerated().map {
            KDPoint(originalIndex: $0.offset, xCoord: $0.element.0, yCoord: $0.element.1)
        }
        if !points.isEmpty {
            KDBush.sortKD(&sortable, left: 0, right: points.count - 1, depth: 0, nodeSize: nodeSize)
        }
        ids = sortable.map(\.originalIndex)
        coords = sortable
    }

    nonisolated func range(minX: Double, minY: Double, maxX: Double, maxY: Double) -> [Int] {
        guard !coords.isEmpty else { return [] }
        var result: [Int] = []
        var stack: [KDStackEntry] = [KDStackEntry(left: 0, right: coords.count - 1, depth: 0)]

        while let entry = stack.popLast() {
            if entry.right - entry.left <= nodeSize {
                for idx in entry.left ... entry.right {
                    let point = coords[idx]
                    if point.xCoord >= minX, point.xCoord <= maxX,
                       point.yCoord >= minY, point.yCoord <= maxY {
                        result.append(ids[idx])
                    }
                }
                continue
            }

            let mid = (entry.left + entry.right) / 2
            let midPt = coords[mid]

            if midPt.xCoord >= minX, midPt.xCoord <= maxX,
               midPt.yCoord >= minY, midPt.yCoord <= maxY {
                result.append(ids[mid])
            }

            let axisBounds = entry.depth % 2 == 0 ? (minX, maxX) : (minY, maxY)
            let axisVal = entry.depth % 2 == 0 ? midPt.xCoord : midPt.yCoord
            if axisBounds.0 <= axisVal {
                stack.append(KDStackEntry(left: entry.left, right: mid - 1, depth: entry.depth + 1))
            }
            if axisBounds.1 >= axisVal {
                stack.append(KDStackEntry(left: mid + 1, right: entry.right, depth: entry.depth + 1))
            }
        }

        return result
    }

    nonisolated func within(centerX: Double, centerY: Double, radius: Double) -> [Int] {
        guard !coords.isEmpty else { return [] }
        let radiusSq = radius * radius
        var result: [Int] = []
        var stack: [KDStackEntry] = [KDStackEntry(left: 0, right: coords.count - 1, depth: 0)]

        while let entry = stack.popLast() {
            if entry.right - entry.left <= nodeSize {
                for idx in entry.left ... entry.right {
                    let point = coords[idx]
                    let deltaX = point.xCoord - centerX
                    let deltaY = point.yCoord - centerY
                    if deltaX * deltaX + deltaY * deltaY <= radiusSq {
                        result.append(ids[idx])
                    }
                }
                continue
            }

            let mid = (entry.left + entry.right) / 2
            let midPt = coords[mid]

            let deltaX = midPt.xCoord - centerX
            let deltaY = midPt.yCoord - centerY
            if deltaX * deltaX + deltaY * deltaY <= radiusSq {
                result.append(ids[mid])
            }

            let axisBounds = entry.depth % 2 == 0
                ? (centerX - radius, centerX + radius)
                : (centerY - radius, centerY + radius)
            let axisVal = entry.depth % 2 == 0 ? midPt.xCoord : midPt.yCoord
            if axisBounds.0 <= axisVal {
                stack.append(KDStackEntry(left: entry.left, right: mid - 1, depth: entry.depth + 1))
            }
            if axisBounds.1 >= axisVal {
                stack.append(KDStackEntry(left: mid + 1, right: entry.right, depth: entry.depth + 1))
            }
        }

        return result
    }

    // MARK: - KD-Sort

    private nonisolated static func sortKD(
        _ items: inout [KDPoint],
        left: Int, right: Int, depth: Int, nodeSize: Int
    ) {
        guard right - left > nodeSize else { return }
        let mid = (left + right) / 2
        selectNth(&items, left: left, right: right, target: mid, depth: depth)
        sortKD(&items, left: left, right: mid - 1, depth: depth + 1, nodeSize: nodeSize)
        sortKD(&items, left: mid + 1, right: right, depth: depth + 1, nodeSize: nodeSize)
    }

    private nonisolated static func coordValue(_ point: KDPoint, useX: Bool) -> Double {
        useX ? point.xCoord : point.yCoord
    }

    private nonisolated static func selectNth(
        _ items: inout [KDPoint],
        left: Int, right: Int, target: Int, depth: Int
    ) {
        var low = left
        var high = right
        let useX = depth % 2 == 0

        while high > low {
            if high - low > 600 {
                let count = Double(high - low + 1)
                let pos = Double(target - low + 1)
                let logN = log(count)
                let step = 0.5 * exp(2 * logN / 3)
                let deviation = 0.5 * sqrt(logN * step * (count - step) / count) * (pos - count / 2 < 0 ? -1 : 1)
                let newLow = max(low, Int(Double(target) - pos * step / count + deviation))
                let newHigh = min(high, Int(Double(target) + (count - pos) * step / count + deviation))
                selectNth(&items, left: newLow, right: newHigh, target: target, depth: depth)
            }

            let pivot = coordValue(items[target], useX: useX)
            var scanLeft = low
            var scanRight = high

            items.swapAt(low, target)
            if coordValue(items[high], useX: useX) > pivot {
                items.swapAt(low, high)
            }

            while scanLeft < scanRight {
                items.swapAt(scanLeft, scanRight)
                scanLeft += 1
                scanRight -= 1
                while coordValue(items[scanLeft], useX: useX) < pivot {
                    scanLeft += 1
                }
                while coordValue(items[scanRight], useX: useX) > pivot {
                    scanRight -= 1
                }
            }

            if coordValue(items[low], useX: useX) == pivot {
                items.swapAt(low, scanRight)
            } else {
                scanRight += 1
                items.swapAt(scanRight, high)
            }

            if scanRight <= target {
                low = scanRight + 1
            }
            if target <= scanRight {
                high = scanRight - 1
            }
        }
    }
}
