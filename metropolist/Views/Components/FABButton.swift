import SwiftUI

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InnerBody(configuration: configuration)
    }

    private struct InnerBody: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct FABButton: View {
    let action: () -> Void

    @State private var tapTrigger = false

    var body: some View {
        Button {
            tapTrigger.toggle()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.blue, in: Circle())
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(FABButtonStyle())
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: tapTrigger)
    }
}
