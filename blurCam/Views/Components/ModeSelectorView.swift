import SwiftUI

/// A mode selector that displays camera modes (photo/video) in a horizontal layout.
/// Supports tap and swipe gestures for switching between modes.
/// Mimics the iOS Camera app's mode selector behavior.
struct ModeSelectorView: View {
    @Binding var selectedMode: CameraMode
    let isRecording: Bool

    /// Drag gesture state for swipe handling
    @State private var dragOffset: CGFloat = 0

    /// Minimum drag distance to trigger a mode switch
    private let swipeThreshold: CGFloat = 30

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.space8) {
            ForEach(CameraMode.allCases, id: \.self) { mode in
                VStack(spacing: DesignTokens.Spacing.space1 + 1) {
                    Text(mode.rawValue)
                        .font(.system(
                            size: DesignTokens.Typography.sm,
                            weight: mode == selectedMode
                                ? DesignTokens.Typography.Weight.semibold
                                : DesignTokens.Typography.Weight.normal
                        ))
                        .foregroundStyle(
                            mode == selectedMode
                                ? DesignTokens.Colors.warning
                                : DesignTokens.Colors.textTertiary
                        )
                        .tracking(0.4)

                    // Active indicator dot beneath selected mode label
                    Circle()
                        .fill(DesignTokens.Colors.warning)
                        .frame(width: 5, height: 5)
                        .opacity(mode == selectedMode ? 1.0 : 0.0)
                }
                .onTapGesture {
                    guard !isRecording else { return }
                    withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                        selectedMode = mode
                    }
                }
                .accessibilityIdentifier(mode == .photo ? "photoModeLabel" : "videoModeLabel")
                .accessibilityAddTraits(mode == selectedMode ? .isSelected : [])
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: swipeThreshold)
                .onEnded { value in
                    guard !isRecording else { return }
                    let horizontalDrag = value.translation.width

                    withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                        if horizontalDrag < -swipeThreshold {
                            // Swipe left -> move to next mode (video)
                            if selectedMode == .photo {
                                selectedMode = .video
                            }
                        } else if horizontalDrag > swipeThreshold {
                            // Swipe right -> move to previous mode (photo)
                            if selectedMode == .video {
                                selectedMode = .photo
                            }
                        }
                    }
                }
        )
        .padding(.top, DesignTokens.Spacing.space3)
        .accessibilityIdentifier("modeSwitchArea")
    }
}
