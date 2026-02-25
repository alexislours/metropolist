import SwiftUI

struct OnboardingPageView<Preview: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            preview()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 120)
        }
    }
}
