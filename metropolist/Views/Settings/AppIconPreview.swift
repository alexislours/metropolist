import SwiftUI

struct AppIconPreview: View {
    let option: AppIconOption
    let isSelected: Bool
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(option.backgroundColor)

            Image("SubwayIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(option.foregroundColor)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}
