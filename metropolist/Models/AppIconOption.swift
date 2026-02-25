import SwiftUI

struct AppIconOption: Identifiable, Hashable {
    let id: String
    let lineName: String
    let mode: TransitMode
    let bgHex: String
    let fgHex: String

    var backgroundColor: Color {
        Color(hex: bgHex)
    }

    var foregroundColor: Color {
        Color(hex: fgHex)
    }

    /// The name passed to `setAlternateIconName`. `nil` resets to default.
    var iconName: String? {
        id == "MetropolistIcon" ? nil : id
    }

    static let defaultIcon = AppIconOption(
        id: "MetropolistIcon",
        lineName: String(localized: "Default", comment: "App icon: default icon label"),
        mode: .metro,
        bgHex: "#ffffff",
        fgHex: "#000000"
    )

    static let modeOrder: [TransitMode] = [.metro, .rer, .train, .tram]

    static let allOptions: [(mode: TransitMode, label: String, icons: [AppIconOption])] = [
        (.metro, String(localized: "Metro", comment: "App icon: metro section"), [
            AppIconOption(id: "Metro1", lineName: "1", mode: .metro, bgHex: "#ffbe00", fgHex: "#000000"),
            AppIconOption(id: "Metro2", lineName: "2", mode: .metro, bgHex: "#0055c8", fgHex: "#ffffff"),
            AppIconOption(id: "Metro3", lineName: "3", mode: .metro, bgHex: "#6e6e00", fgHex: "#ffffff"),
            AppIconOption(id: "Metro3B", lineName: "3B", mode: .metro, bgHex: "#6ec4e8", fgHex: "#000000"),
            AppIconOption(id: "Metro4", lineName: "4", mode: .metro, bgHex: "#a0006e", fgHex: "#ffffff"),
            AppIconOption(id: "Metro5", lineName: "5", mode: .metro, bgHex: "#ff7e2e", fgHex: "#000000"),
            AppIconOption(id: "Metro6", lineName: "6", mode: .metro, bgHex: "#6eca97", fgHex: "#000000"),
            AppIconOption(id: "Metro7", lineName: "7", mode: .metro, bgHex: "#f49fb3", fgHex: "#000000"),
            AppIconOption(id: "Metro7B", lineName: "7B", mode: .metro, bgHex: "#6eca97", fgHex: "#000000"),
            AppIconOption(id: "Metro8", lineName: "8", mode: .metro, bgHex: "#d282be", fgHex: "#000000"),
            AppIconOption(id: "Metro9", lineName: "9", mode: .metro, bgHex: "#b6bd00", fgHex: "#000000"),
            AppIconOption(id: "Metro10", lineName: "10", mode: .metro, bgHex: "#c9910d", fgHex: "#000000"),
            AppIconOption(id: "Metro11", lineName: "11", mode: .metro, bgHex: "#704b1c", fgHex: "#ffffff"),
            AppIconOption(id: "Metro12", lineName: "12", mode: .metro, bgHex: "#007852", fgHex: "#ffffff"),
            AppIconOption(id: "Metro13", lineName: "13", mode: .metro, bgHex: "#6ec4e8", fgHex: "#000000"),
            AppIconOption(id: "Metro14", lineName: "14", mode: .metro, bgHex: "#62259d", fgHex: "#ffffff"),
        ]),
        (.rer, String(localized: "RER", comment: "App icon: RER section"), [
            AppIconOption(id: "RERA", lineName: "A", mode: .rer, bgHex: "#eb2132", fgHex: "#ffffff"),
            AppIconOption(id: "RERB", lineName: "B", mode: .rer, bgHex: "#5091cb", fgHex: "#ffffff"),
            AppIconOption(id: "RERC", lineName: "C", mode: .rer, bgHex: "#ffcc30", fgHex: "#000000"),
            AppIconOption(id: "RERD", lineName: "D", mode: .rer, bgHex: "#008b5b", fgHex: "#ffffff"),
            AppIconOption(id: "RERE", lineName: "E", mode: .rer, bgHex: "#b94e9a", fgHex: "#ffffff"),
        ]),
        (.train, String(localized: "Transilien", comment: "App icon: Transilien section"), [
            AppIconOption(id: "TransilienH", lineName: "H", mode: .train, bgHex: "#84653d", fgHex: "#ffffff"),
            AppIconOption(id: "TransilienJ", lineName: "J", mode: .train, bgHex: "#cec73d", fgHex: "#000000"),
            AppIconOption(id: "TransilienK", lineName: "K", mode: .train, bgHex: "#9b9842", fgHex: "#ffffff"),
            AppIconOption(id: "TransilienL", lineName: "L", mode: .train, bgHex: "#c4a4cc", fgHex: "#000000"),
            AppIconOption(id: "TransilienN", lineName: "N", mode: .train, bgHex: "#00b297", fgHex: "#ffffff"),
            AppIconOption(id: "TransilienP", lineName: "P", mode: .train, bgHex: "#f58f53", fgHex: "#000000"),
            AppIconOption(id: "TransilienR", lineName: "R", mode: .train, bgHex: "#f49fb3", fgHex: "#000000"),
            AppIconOption(id: "TransilienU", lineName: "U", mode: .train, bgHex: "#b6134c", fgHex: "#ffffff"),
            AppIconOption(id: "TransilienV", lineName: "V", mode: .train, bgHex: "#9f9825", fgHex: "#ffffff"),
        ]),
        (.tram, String(localized: "Tram", comment: "App icon: tram section"), [
            AppIconOption(id: "TramT1", lineName: "T1", mode: .tram, bgHex: "#003ca6", fgHex: "#ffffff"),
            AppIconOption(id: "TramT2", lineName: "T2", mode: .tram, bgHex: "#cf009e", fgHex: "#ffffff"),
            AppIconOption(id: "TramT3a", lineName: "T3a", mode: .tram, bgHex: "#ff7e2e", fgHex: "#000000"),
            AppIconOption(id: "TramT3b", lineName: "T3b", mode: .tram, bgHex: "#00ae41", fgHex: "#ffffff"),
            AppIconOption(id: "TramT4", lineName: "T4", mode: .tram, bgHex: "#dc9600", fgHex: "#000000"),
            AppIconOption(id: "TramT5", lineName: "T5", mode: .tram, bgHex: "#62259d", fgHex: "#ffffff"),
            AppIconOption(id: "TramT6", lineName: "T6", mode: .tram, bgHex: "#e2231a", fgHex: "#ffffff"),
            AppIconOption(id: "TramT7", lineName: "T7", mode: .tram, bgHex: "#704b1c", fgHex: "#ffffff"),
            AppIconOption(id: "TramT8", lineName: "T8", mode: .tram, bgHex: "#837902", fgHex: "#ffffff"),
            AppIconOption(id: "TramT9", lineName: "T9", mode: .tram, bgHex: "#3c91dc", fgHex: "#ffffff"),
            AppIconOption(id: "TramT10", lineName: "T10", mode: .tram, bgHex: "#6e6e00", fgHex: "#ffffff"),
            AppIconOption(id: "TramT11", lineName: "T11", mode: .tram, bgHex: "#ff5a00", fgHex: "#000000"),
            AppIconOption(id: "TramT12", lineName: "T12", mode: .tram, bgHex: "#a50034", fgHex: "#ffffff"),
            AppIconOption(id: "TramT13", lineName: "T13", mode: .tram, bgHex: "#8d653d", fgHex: "#ffffff"),
            AppIconOption(id: "TramT14", lineName: "T14", mode: .tram, bgHex: "#00a092", fgHex: "#ffffff"),
        ]),
    ]

    static func find(byID id: String) -> AppIconOption? {
        if id == defaultIcon.id { return defaultIcon }
        for group in allOptions {
            if let match = group.icons.first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }
}
