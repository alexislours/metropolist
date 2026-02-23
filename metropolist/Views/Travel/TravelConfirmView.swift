import SwiftUI
import TransitModels

struct TravelConfirmView: View {
    @Bindable var viewModel: TravelFlowViewModel

    @State private var confirmTrigger = false

    var body: some View {
        List {
            if let line = viewModel.selectedLine, let variant = viewModel.selectedVariant {
                Section {
                    HStack {
                        LineBadge(line: line)
                        Text(variant.headsign)
                            .font(.subheadline)
                    }
                }

                Section(String(localized: "Your journey", comment: "Travel confirm: journey stops section header")) {
                    let lineColor = Color(hex: line.color)
                    let stops = viewModel.intermediateStops

                    VStack(spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.order) { index, stop in
                            let isEndpoint = stop.stationSourceID == viewModel.originStation?.sourceID
                                || stop.stationSourceID == viewModel.destinationStation?.sourceID
                            let isFirst = index == 0
                            let isLast = index == stops.count - 1

                            HStack(spacing: 12) {
                                ZStack {
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(isFirst ? .clear : lineColor)
                                            .frame(width: 3)
                                        Rectangle()
                                            .fill(isLast ? .clear : lineColor)
                                            .frame(width: 3)
                                    }

                                    Circle()
                                        .fill(isEndpoint ? lineColor : lineColor.opacity(0.3))
                                        .frame(width: isEndpoint ? 12 : 6, height: isEndpoint ? 12 : 6)
                                        .overlay {
                                            if isEndpoint {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                            }
                                        }
                                }
                                .frame(width: 20)

                                Text(viewModel.intermediateStationNames[stop.stationSourceID] ?? stop.stationSourceID)
                                    .font(isEndpoint ? .subheadline.weight(.semibold) : .subheadline)
                                    .foregroundStyle(isEndpoint ? .primary : .secondary)

                                Spacer()
                            }
                            .frame(height: isEndpoint ? 36 : 28)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                confirmTrigger.toggle()
                viewModel.confirmTravel()
            } label: {
                Group {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "Confirm journey", comment: "Travel confirm: confirm button label"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(viewModel.isProcessing)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .accessibilityIdentifier("button-confirm-travel")
            .sensoryFeedback(.success, trigger: confirmTrigger)
        }
        .navigationTitle(String(localized: "Confirm travel", comment: "Travel confirm: navigation title"))
    }
}
