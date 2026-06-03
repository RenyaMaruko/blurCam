import SwiftUI

/// TikTok Live-style chat message overlay that displays YouTube live chat messages
/// on top of the camera preview. Messages slide in from the bottom and older messages
/// scroll up and fade out.
struct LiveChatOverlayView: View {
    /// The chat messages to display (newest last)
    let messages: [LiveChatMessage]

    /// Maximum number of visible messages
    private let maxVisibleMessages = 6

    /// The messages to actually render (limited to maxVisibleMessages)
    private var visibleMessages: [LiveChatMessage] {
        Array(messages.suffix(maxVisibleMessages))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.space1) {
                    ForEach(messages) { message in
                        LiveChatMessageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.space1)
            }
            .onChange(of: messages.last?.id) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 250)
        .accessibilityIdentifier("liveChatOverlay")
    }
}

/// A single chat message row in the overlay
struct LiveChatMessageRow: View {
    let message: LiveChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.space2) {
            // Profile image
            AsyncImage(url: message.authorImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(DesignTokens.Colors.surface)
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                // Author name with role indicators
                HStack(spacing: 2) {
                    if message.isOwner {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(DesignTokens.Colors.warning)
                    } else if message.isModerator {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }

                    Text(message.authorName)
                        .font(.system(
                            size: DesignTokens.Typography.xs,
                            weight: DesignTokens.Typography.Weight.bold
                        ))
                        .foregroundStyle(authorColor)
                        .lineLimit(1)
                }

                // Message text
                Text(message.message)
                    .font(.system(
                        size: DesignTokens.Typography.sm,
                        weight: DesignTokens.Typography.Weight.normal
                    ))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.space2)
        .padding(.vertical, DesignTokens.Spacing.space1)
        .background(chatBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .accessibilityIdentifier("chatMessage_\(message.id)")
        .accessibilityLabel("\(message.authorName): \(message.message)")
    }

    /// Author name color based on role
    private var authorColor: Color {
        if message.isOwner {
            return DesignTokens.Colors.warning
        } else if message.isModerator {
            return DesignTokens.Colors.accent
        } else if message.isSuperChat {
            return DesignTokens.Colors.warning
        } else {
            return DesignTokens.Colors.accent
        }
    }

    /// Background with super chat highlight
    @ViewBuilder
    private var chatBackground: some View {
        if message.isSuperChat {
            // Super Chat gets a slightly more prominent background
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(DesignTokens.Colors.warning.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .stroke(DesignTokens.Colors.warning.opacity(0.25), lineWidth: 0.5)
                )
        } else {
            // Standard semi-transparent background
            Color.black.opacity(0.45)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LiveChatOverlayView_Previews: PreviewProvider {
    static var sampleMessages: [LiveChatMessage] = [
        LiveChatMessage(id: "1", authorName: "User1", message: "Hello everyone!"),
        LiveChatMessage(id: "2", authorName: "Mod", message: "Welcome to the stream!", isModerator: true),
        LiveChatMessage(id: "3", authorName: "Owner", message: "Thanks for watching!", isOwner: true),
        LiveChatMessage(id: "4", authorName: "Fan123", message: "This is amazing content"),
        LiveChatMessage(id: "5", authorName: "SuperFan", message: "Keep it up!", isSuperChat: true, superChatAmount: "$5.00"),
        LiveChatMessage(id: "6", authorName: "Viewer", message: "Great stream today"),
    ]

    static var previews: some View {
        ZStack {
            Color.black
            VStack {
                Spacer()
                LiveChatOverlayView(messages: sampleMessages)
                    .frame(maxWidth: 280)
                    .padding(.leading, DesignTokens.Spacing.space3)
                    .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
