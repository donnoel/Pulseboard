import SwiftUI

enum PulseSpacing {
    static let tiny: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 28
}

enum PulseCornerRadius {
    static let chip: CGFloat = 14
    static let card: CGFloat = 20
    static let panel: CGFloat = 26
}

enum PulsePalette {
    static let backgroundTop = Color(red: 0.08, green: 0.11, blue: 0.19)
    static let backgroundBottom = Color(red: 0.02, green: 0.04, blue: 0.08)
    static let accent = Color(red: 0.22, green: 0.79, blue: 0.93)
    static let success = Color(red: 0.37, green: 0.80, blue: 0.47)
    static let warning = Color(red: 0.98, green: 0.67, blue: 0.22)
    static let danger = Color(red: 0.94, green: 0.34, blue: 0.33)

    static func color(for severity: PulseSeverity) -> Color {
        switch severity {
        case .low:
            return success
        case .moderate:
            return warning
        case .high:
            return danger
        case .severe:
            return danger
        case .unknown:
            return .gray
        }
    }

    static func color(for category: PulseCategory) -> Color {
        switch category {
        case .all:
            return accent
        case .earthquakes:
            return Color(red: 0.40, green: 0.84, blue: 0.96)
        case .hazards:
            return warning
        case .alerts:
            return danger
        }
    }
}

struct PulseGlassCardStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        let style = prominent
            ? Glass.regular.tint(.white.opacity(0.16))
            : Glass.regular

        content
            .padding(PulseSpacing.medium)
            .glassEffect(style, in: .rect(cornerRadius: PulseCornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PulseCornerRadius.card, style: .continuous)
                    .stroke(.white.opacity(prominent ? 0.24 : 0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(prominent ? 0.22 : 0.14), radius: prominent ? 18 : 10, y: 8)
    }
}

extension View {
    func pulseGlassCard(prominent: Bool = false) -> some View {
        modifier(PulseGlassCardStyle(prominent: prominent))
    }
}

struct PulseChipButtonStyle: ButtonStyle {
    let selected: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let style = selected
            ? Glass.regular.tint(tint.opacity(0.28)).interactive()
            : Glass.regular.interactive()

        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, PulseSpacing.medium)
            .padding(.vertical, PulseSpacing.small)
            .glassEffect(style, in: .capsule)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(selected ? tint.opacity(0.9) : .white.opacity(0.20), lineWidth: 1)
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.9))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
