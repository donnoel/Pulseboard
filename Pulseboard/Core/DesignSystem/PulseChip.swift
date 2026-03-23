import SwiftUI

struct PulseChip: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseSpacing.tiny) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PulseChipButtonStyle(selected: selected, tint: tint))
        .accessibilityElement(children: .combine)
    }
}
