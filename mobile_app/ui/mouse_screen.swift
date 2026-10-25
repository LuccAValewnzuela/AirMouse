import SwiftUI

struct MouseScreen: View {
    @StateObject private var coordinator = AppCoordinator()
    @AppStorage("sensitivity") private var sensitivity: Double = 4000

    var body: some View {
        VStack(spacing: 24) {
            buttonsSection
            connectionSection
            if coordinator.trackingLost {
                trackingLostBanner
            }
            trackingSection
            sensitivitySection
            debugSection
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            coordinator.setSensitivity(Float(sensitivity))
        }
    }

    private var connectionSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 14, height: 14)
            Text(statusLabel)
                .font(.headline)
            Spacer()
            Button(coordinator.connectionState == .connected ? "Disconnect" : "Connect") {
                if coordinator.connectionState == .connected {
                    coordinator.disconnect()
                } else {
                    coordinator.connect()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statusColor: Color {
        switch coordinator.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        }
    }

    private var statusLabel: String {
        switch coordinator.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        }
    }

    private var trackingLostBanner: some View {
        Text("Tracking lost — move the phone slowly to reanchor")
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var trackingSection: some View {
        HStack(spacing: 16) {
            Button(coordinator.isTracking ? "Stop tracking" : "Start tracking") {
                if coordinator.isTracking {
                    coordinator.stopTracking()
                } else {
                    coordinator.startTracking()
                }
            }
            .buttonStyle(.bordered)

            Button("Reset reference") {
                coordinator.resetReference()
            }
            .buttonStyle(.bordered)
        }
    }

    private var buttonsSection: some View {
        HStack(spacing: 16) {
            ClickButton(button: .left, coordinator: coordinator)
            ClickButton(button: .right, coordinator: coordinator)
        }
    }

    private var sensitivitySection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Sensitivity")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(sensitivity)) px/m")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(
                value: $sensitivity,
                in: 800...10000,
                step: 100,
                onEditingChanged: { editing in
                    if !editing {
                        coordinator.setSensitivity(Float(sensitivity))
                    }
                }
            )
        }
    }

    private var debugSection: some View {
        Text(String(format: "dx: %+.4f  dy: %+.4f",
                    coordinator.debugDisplacement.x,
                    coordinator.debugDisplacement.y))
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.secondary)
    }
}

struct ClickButton: View {
    let button: ButtonOptions
    let coordinator: AppCoordinator
    @State private var isDown = false

    var body: some View {
        Text(button == .left ? "Left click" : "Right click")
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(isDown ? Color.blue.opacity(0.5) : Color.blue.opacity(0.15))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDown {
                            isDown = true
                            coordinator.press(button)
                        }
                    }
                    .onEnded { _ in
                        isDown = false
                        coordinator.release(button)
                    }
            )
    }
}
