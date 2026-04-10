import SwiftUI

struct CookModeView: View {
    let steps: [CookingStep]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var timerSeconds: Int?
    @State private var timerRemaining: Int = 0
    @State private var timerActive = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.gray)
                }

                Spacer()

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Spacer()

                Text("\(currentStep + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.surface)
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
            .padding(.horizontal, 16)

            Spacer()

            // Step content
            VStack(spacing: 20) {
                Text("STEP \(currentStep + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
                    .tracking(2)

                if currentStep < steps.count {
                    Text(steps[currentStep].instruction)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // Timer
            if let detected = detectedTime, !timerActive {
                Button {
                    startTimer(seconds: detected)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        Text("Start \(formatTime(detected)) timer?")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.bottom, 16)
            }

            if timerActive {
                VStack(spacing: 4) {
                    Text(formatTime(timerRemaining))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(timerRemaining <= 10 ? .red : .orange)

                    Button("Cancel timer") {
                        stopTimer()
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                }
                .padding(.bottom, 16)
            }

            // Navigation buttons
            HStack(spacing: 16) {
                Button {
                    withAnimation { currentStep = max(0, currentStep - 1) }
                    stopTimer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .opacity(currentStep > 0 ? 1 : 0.3)
                .disabled(currentStep == 0)

                Spacer()

                if currentStep < steps.count - 1 {
                    Button {
                        withAnimation { currentStep += 1 }
                        stopTimer()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            stopTimer()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 && currentStep < steps.count - 1 {
                        withAnimation { currentStep += 1 }
                        stopTimer()
                    } else if value.translation.width > 50 && currentStep > 0 {
                        withAnimation { currentStep -= 1 }
                        stopTimer()
                    }
                }
        )
    }

    // MARK: - Helpers

    private var progress: CGFloat {
        guard !steps.isEmpty else { return 0 }
        return CGFloat(currentStep + 1) / CGFloat(steps.count)
    }

    private var detectedTime: Int? {
        guard currentStep < steps.count else { return nil }
        let text = steps[currentStep].instruction
        return parseTime(from: text)
    }

    private func parseTime(from text: String) -> Int? {
        let pattern = /(\d+)\s*(min|minute|minutes|hour|hours|sec|second|seconds)/
        guard let match = text.firstMatch(of: pattern) else { return nil }

        let value = Int(match.1) ?? 0
        let unit = String(match.2).lowercased()

        switch unit {
        case "hour", "hours": return value * 3600
        case "min", "minute", "minutes": return value * 60
        case "sec", "second", "seconds": return value
        default: return nil
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return "\(h)h \(m)m"
        } else if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m) min"
        } else {
            return "\(seconds)s"
        }
    }

    private func startTimer(seconds: Int) {
        timerRemaining = seconds
        timerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            Task { @MainActor in
                if timerRemaining > 0 {
                    timerRemaining -= 1
                } else {
                    stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerActive = false
    }
}
