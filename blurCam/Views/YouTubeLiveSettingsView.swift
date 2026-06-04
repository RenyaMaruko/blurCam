import SwiftUI

/// View for YouTube live broadcast detailed settings.
/// Accessible from the streaming destination edit screen when YouTube Live is selected.
/// Provides Google account management, broadcast title/description, privacy,
/// category, latency, chat, and DVR settings.
struct YouTubeLiveSettingsView: View {

    @ObservedObject var viewModel: YouTubeLiveSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.space6) {

                // MARK: - Google Account Section

                accountSection

                // MARK: - Broadcast Settings

                broadcastSettingsSection

                // MARK: - Privacy Setting

                privacySection

                // MARK: - Advanced Options

                advancedOptionsSection

                // MARK: - Validation Error

                if let error = viewModel.validationError {
                    validationErrorBanner(message: error.errorDescription ?? "")
                }

                // MARK: - Save Button

                Button {
                    if viewModel.saveSettings() {
                        dismiss()
                    }
                } label: {
                    Text("保存")
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.space4)
                        .background(DesignTokens.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                }
                .padding(.horizontal, DesignTokens.Spacing.space2)
                .padding(.top, DesignTokens.Spacing.space2)
                .accessibilityIdentifier("saveLiveSettingsButton")
                .accessibilityLabel("ライブ設定を保存")
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.top, DesignTokens.Spacing.space4)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }
        .background(DesignTokens.Colors.primary)
        .navigationTitle("ライブの詳細設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignTokens.Colors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.restorePreviousSignIn()
        }
        .accessibilityIdentifier("youTubeLiveSettingsView")
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "Googleアカウント")

            VStack(spacing: 0) {
                switch viewModel.authState {
                case .signedOut, .error:
                    signedOutAccountView

                case .signingIn:
                    signingInAccountView

                case .signedIn(let userInfo):
                    signedInAccountView(userInfo: userInfo)
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
    }

    private var signedOutAccountView: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            VStack(spacing: DesignTokens.Spacing.space2) {
                Image(systemName: "person.circle")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text("Googleアカウントでログイン")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Text("YouTube Live配信を自動で作成するにはGoogleアカウントが必要です")
                    .font(.system(size: DesignTokens.Typography.sm))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignTokens.Spacing.space4)

            Button {
                Task { await viewModel.signIn() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.space2) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: DesignTokens.Typography.base))
                    Text("Googleでログイン")
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.space3)
                .background(DesignTokens.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.bottom, DesignTokens.Spacing.space4)
            .accessibilityIdentifier("liveSettingsGoogleSignInButton")
            .accessibilityLabel("Googleでログイン")
        }
    }

    private var signingInAccountView: some View {
        HStack(spacing: DesignTokens.Spacing.space3) {
            ProgressView()
                .tint(DesignTokens.Colors.textSecondary)
            Text("サインイン中...")
                .font(.system(size: DesignTokens.Typography.base))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.space6)
    }

    private func signedInAccountView(userInfo: GoogleUserInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.space3) {
                // Profile image or placeholder
                if let profileURL = userInfo.profileImageURL {
                    AsyncImage(url: profileURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        accountProfilePlaceholder
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    accountProfilePlaceholder
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space1) {
                    Text(userInfo.displayName)
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("liveSettingsDisplayName")

                    Text(userInfo.email)
                        .font(.system(size: DesignTokens.Typography.sm))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .accessibilityIdentifier("liveSettingsEmail")
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: DesignTokens.Typography.lg))
                    .foregroundStyle(DesignTokens.Colors.success)
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.vertical, DesignTokens.Spacing.space3)
            .accessibilityIdentifier("liveSettingsProfileSection")

            Divider()
                .background(DesignTokens.Colors.border)

            Button {
                viewModel.signOut()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                        .font(.system(size: DesignTokens.Typography.sm))
                    Text("ログアウト")
                        .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                }
                .foregroundStyle(DesignTokens.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.space3)
            }
            .accessibilityIdentifier("liveSettingsSignOutButton")
            .accessibilityLabel("ログアウト")
        }
    }

    private var accountProfilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.surface)
                .frame(width: 44, height: 44)
            Image(systemName: "person.fill")
                .font(.system(size: DesignTokens.Typography.lg))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .accessibilityIdentifier("liveSettingsProfilePlaceholder")
    }

    // MARK: - Broadcast Settings Section

    private var broadcastSettingsSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "配信設定")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space5) {
                    // Title input
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "textformat")
                                .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                            Text("タイトル")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }

                        TextField("blurCam Live", text: $viewModel.title)
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.space3)
                            .padding(.vertical, DesignTokens.Spacing.space3)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .fill(DesignTokens.Colors.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .stroke(
                                        viewModel.validationError == .emptyTitle
                                            ? DesignTokens.Colors.error
                                            : DesignTokens.Colors.border,
                                        lineWidth: 1
                                    )
                            )
                            .accessibilityIdentifier("liveSettingsTitleField")
                            .onChange(of: viewModel.title) { _, _ in
                                viewModel.validationError = nil
                            }
                    }

                    Divider()
                        .background(DesignTokens.Colors.border)

                    // Description input (multiline)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                            Text("説明文")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }

                        TextEditor(text: $viewModel.broadcastDescription)
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80, maxHeight: 160)
                            .padding(.horizontal, DesignTokens.Spacing.space3)
                            .padding(.vertical, DesignTokens.Spacing.space2)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .fill(DesignTokens.Colors.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                            .accessibilityIdentifier("liveSettingsDescriptionField")

                        Text("任意 - 配信の説明を入力できます")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space4)
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "公開設定")

            VStack(spacing: 0) {
                ForEach(Array(YouTubeBroadcastPrivacy.allCases.enumerated()), id: \.element) { index, privacyOption in
                    Button {
                        withAnimation(.easeInOut(duration: DesignTokens.Motion.fast)) {
                            viewModel.privacy = privacyOption
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.space3) {
                            Image(systemName: privacyIconName(for: privacyOption))
                                .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(
                                    viewModel.privacy == privacyOption
                                        ? DesignTokens.Colors.accent
                                        : DesignTokens.Colors.textSecondary
                                )
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(privacyOption.displayName)
                                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Text(privacyDescription(for: privacyOption))
                                    .font(.system(size: DesignTokens.Typography.xs))
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }

                            Spacer()

                            if viewModel.privacy == privacyOption {
                                Image(systemName: "checkmark")
                                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.semibold))
                                    .foregroundStyle(DesignTokens.Colors.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.space4)
                        .padding(.vertical, DesignTokens.Spacing.space3)
                        .background(
                            viewModel.privacy == privacyOption
                                ? DesignTokens.Colors.accent.opacity(0.06)
                                : Color.clear
                        )
                    }
                    .accessibilityIdentifier("privacyOption_\(privacyOption.rawValue)")
                    .accessibilityLabel(privacyOption.displayName)

                    if index < YouTubeBroadcastPrivacy.allCases.count - 1 {
                        Divider()
                            .background(DesignTokens.Colors.border)
                            .padding(.leading, DesignTokens.Spacing.space4 + 28 + DesignTokens.Spacing.space3)
                    }
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            .accessibilityIdentifier("privacySettingSection")
        }
    }

    // MARK: - Advanced Options Section

    private var advancedOptionsSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "詳細オプション")

            VStack(spacing: 0) {
                // Category picker
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "folder")
                            .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text("カテゴリ")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Menu {
                        ForEach(YouTubeCategory.allCases) { cat in
                            Button {
                                viewModel.category = cat
                            } label: {
                                HStack {
                                    Text(cat.displayName)
                                    if viewModel.category == cat {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.category.displayName)
                                .font(.system(size: DesignTokens.Typography.sm))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: DesignTokens.Typography.xs))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.space3)
                        .padding(.vertical, DesignTokens.Spacing.space3)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .fill(DesignTokens.Colors.primary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("liveSettingsCategoryPicker")
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.top, DesignTokens.Spacing.space4)
                .padding(.bottom, DesignTokens.Spacing.space3)

                Divider()
                    .background(DesignTokens.Colors.border)
                    .padding(.leading, DesignTokens.Spacing.space4)

                // Latency picker
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "speedometer")
                            .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text("遅延設定")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Picker("遅延設定", selection: $viewModel.latencyPreference) {
                        ForEach(YouTubeLatencyPreference.allCases) { latency in
                            Text(latency.displayName).tag(latency)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("liveSettingsLatencyPicker")
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)

                Divider()
                    .background(DesignTokens.Colors.border)
                    .padding(.leading, DesignTokens.Spacing.space4)

                // Chat toggle
                HStack {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text("チャット")
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.enableChat)
                        .labelsHidden()
                        .accessibilityIdentifier("liveSettingsChatToggle")
                        .accessibilityLabel("チャット")
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)

                Divider()
                    .background(DesignTokens.Colors.border)
                    .padding(.leading, DesignTokens.Spacing.space4)

                // DVR toggle
                HStack {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "gobackward")
                            .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DVR")
                                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                            Text("視聴者がライブ配信を巻き戻せます")
                                .font(.system(size: DesignTokens.Typography.xs))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.enableDVR)
                        .labelsHidden()
                        .accessibilityIdentifier("liveSettingsDVRToggle")
                        .accessibilityLabel("DVR")
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            .accessibilityIdentifier("advancedOptionsSection")
        }
    }

    // MARK: - Validation Error Banner

    private func validationErrorBanner(message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.space2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: DesignTokens.Typography.sm))
                .foregroundStyle(DesignTokens.Colors.error)
            Text(message)
                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                .foregroundStyle(DesignTokens.Colors.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.space1)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityIdentifier("liveSettingsValidationError")
    }

    // MARK: - Section Header

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.normal))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.space1)
    }

    // MARK: - Helper Methods

    private func privacyIconName(for privacy: YouTubeBroadcastPrivacy) -> String {
        switch privacy {
        case .publicBroadcast:
            return "globe"
        case .unlisted:
            return "link"
        case .privateBroadcast:
            return "lock"
        }
    }

    private func privacyDescription(for privacy: YouTubeBroadcastPrivacy) -> String {
        switch privacy {
        case .publicBroadcast:
            return "誰でも視聴できます"
        case .unlisted:
            return "URLを知っている人だけが視聴できます"
        case .privateBroadcast:
            return "自分だけが視聴できます"
        }
    }
}
