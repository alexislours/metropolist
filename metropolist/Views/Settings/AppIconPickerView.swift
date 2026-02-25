import SwiftUI

struct AppIconPickerView: View {
    @State private var selectedIconID: String = "MetropolistIcon"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    private let iconSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                defaultSection

                ForEach(AppIconOption.allOptions, id: \.mode) { group in
                    modeSection(label: group.label, icons: group.icons)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "App Icon", comment: "App icon picker: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let current = UIApplication.shared.alternateIconName
            selectedIconID = current ?? "MetropolistIcon"
        }
    }

    // MARK: - Default Icon

    private var defaultSection: some View {
        CardSection(title: String(localized: "DEFAULT", comment: "App icon picker: default section header")) {
            Button {
                setIcon(AppIconOption.defaultIcon)
            } label: {
                HStack(spacing: 14) {
                    AppIconPreview(
                        option: AppIconOption.defaultIcon,
                        isSelected: selectedIconID == "MetropolistIcon",
                        size: iconSize
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Métropolist", comment: "App icon picker: default icon name"))
                            .font(.subheadline.weight(.medium))
                        Text(String(localized: "Default", comment: "App icon picker: default label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedIconID == "MetropolistIcon" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Mode Section

    private func modeSection(label: String, icons: [AppIconOption]) -> some View {
        CardSection(title: label.uppercased()) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(icons) { option in
                    Button {
                        setIcon(option)
                    } label: {
                        VStack(spacing: 4) {
                            AppIconPreview(
                                option: option,
                                isSelected: selectedIconID == option.id,
                                size: iconSize
                            )
                            Text(option.lineName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Icon Switching

    private func setIcon(_ option: AppIconOption) {
        guard selectedIconID != option.id else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
                selectedIconID = option.id
            } catch {}
        }
    }
}
