import SwiftUI

/// View for YouTube API-based live streaming configuration.
/// Handles Google Sign-In, broadcast settings, streaming initiation,
/// lifecycle management (stream health display, metadata editing),
/// and thumbnail selection/upload.
struct YouTubeStreamingView: View {

    @ObservedObject var viewModel: YouTubeStreamingViewModel
    @ObservedObject var cameraViewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showThumbnailPicker: Bool = false
    @State private var editingTitle: String = ""
    @State private var editingDescription: String = ""
    @State private var showMetadataEditor: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.space6) {

                    // MARK: - Account Section

                    accountSection

                    // Only show broadcast settings when signed in
                    if viewModel.authState.isSignedIn {

                        // Show different content based on streaming state
                        if cameraViewModel.isStreaming && cameraViewModel.isYouTubeAPISession {
                            // During YouTube streaming: show status and metadata editor
                            streamHealthSection
                            broadcastStatusSection
                            metadataEditorSection
                        } else {
                            // Before streaming: show configuration
                            thumbnailSection
                            broadcastSettingsSection
                            startStreamingSection
                        }
                    }

                    // MARK: - Re-auth prompt
                    if viewModel.needsReAuth {
                        reAuthPrompt
                    }

                    // MARK: - Error Message
                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.top, DesignTokens.Spacing.space4)
                .padding(.bottom, DesignTokens.Spacing.space8)
            }
            .background(DesignTokens.Colors.primary)
            .navigationTitle("YouTube配信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.Colors.backgroundSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .accessibilityIdentifier("closeYouTubeStreamingButton")
                }
            }
        }
        .task {
            await viewModel.restorePreviousSignIn()
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                onImageSelected: { data, mimeType in
                    viewModel.selectedThumbnailData = data
                    viewModel.selectedThumbnailMimeType = mimeType
                    showThumbnailPicker = false
                },
                onCancel: {
                    showThumbnailPicker = false
                }
            )
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("youTubeStreamingView")
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "Googleアカウント")

            VStack(spacing: 0) {
                switch viewModel.authState {
                case .signedOut, .error:
                    signedOutView

                case .signingIn:
                    signingInView

                case .signedIn(let userInfo):
                    signedInView(userInfo: userInfo)
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
    }

    private var signedOutView: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            VStack(spacing: DesignTokens.Spacing.space2) {
                Image(systemName: "person.circle")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text("Googleアカウントでログイン")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Text("YouTube Live配信を行うにはGoogleアカウントが必要です")
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
            .accessibilityIdentifier("googleSignInButton")
            .accessibilityLabel("Googleでログイン")
        }
    }

    private var signingInView: some View {
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

    private func signedInView(userInfo: GoogleUserInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.space3) {
                // Profile image or placeholder
                if let profileURL = userInfo.profileImageURL {
                    AsyncImage(url: profileURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        profilePlaceholder
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    profilePlaceholder
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space1) {
                    Text(userInfo.displayName)
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text(userInfo.email)
                        .font(.system(size: DesignTokens.Typography.sm))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: DesignTokens.Typography.lg))
                    .foregroundStyle(DesignTokens.Colors.success)
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.vertical, DesignTokens.Spacing.space3)

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
            .accessibilityIdentifier("googleSignOutButton")
            .accessibilityLabel("ログアウト")
        }
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.surface)
                .frame(width: 44, height: 44)
            Image(systemName: "person.fill")
                .font(.system(size: DesignTokens.Typography.lg))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
    }

    // MARK: - Thumbnail Section

    private var thumbnailSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "サムネイル")

            VStack(spacing: DesignTokens.Spacing.space3) {
                // Thumbnail preview
                if let thumbnailData = viewModel.selectedThumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                        .accessibilityIdentifier("thumbnailPreview")
                } else {
                    // Empty state placeholder
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Colors.backgroundSecondary)
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: DesignTokens.Spacing.space2) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28, weight: .thin))
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                Text("サムネイル未設定")
                                    .font(.system(size: DesignTokens.Typography.sm))
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                        .accessibilityIdentifier("thumbnailPlaceholder")
                }

                HStack(spacing: DesignTokens.Spacing.space3) {
                    Button {
                        showThumbnailPicker = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: DesignTokens.Typography.sm))
                            Text(viewModel.selectedThumbnailData != nil ? "サムネイルを変更" : "サムネイルを選択")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                        }
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.space3)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.accent, lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("selectThumbnailButton")
                    .accessibilityLabel("サムネイルを選択")

                    if viewModel.selectedThumbnailData != nil {
                        Button {
                            viewModel.selectedThumbnailData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DesignTokens.Typography.lg))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                        .accessibilityIdentifier("removeThumbnailButton")
                        .accessibilityLabel("サムネイルを削除")
                    }
                }

                // Upload status
                if viewModel.isUploadingThumbnail {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        ProgressView()
                            .tint(DesignTokens.Colors.textSecondary)
                            .scaleEffect(0.8)
                        Text("サムネイルをアップロード中...")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }

                if viewModel.thumbnailUploadSuccess {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.success)
                        Text("サムネイルをアップロードしました")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.success)
                    }
                }

                Text("任意 - 配信のサムネイル画像を設定できます（JPEG/PNG）")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.space1)
        }
        .accessibilityIdentifier("thumbnailSection")
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

                        TextField("blurCam Live", text: $viewModel.broadcastTitle)
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
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                            .accessibilityIdentifier("broadcastTitleField")
                    }

                    Divider()
                        .background(DesignTokens.Colors.border)

                    // Description input
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                            Text("説明")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }

                        TextField("配信の説明（任意）", text: $viewModel.broadcastDescription)
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
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                            .accessibilityIdentifier("broadcastDescriptionField")
                    }

                    Divider()
                        .background(DesignTokens.Colors.border)

                    // Privacy picker
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "lock")
                                .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                            Text("公開設定")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }

                        Picker("公開設定", selection: $viewModel.broadcastPrivacy) {
                            ForEach(YouTubeBroadcastPrivacy.allCases, id: \.self) { privacy in
                                Text(privacy.displayName).tag(privacy)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("broadcastPrivacyPicker")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space4)
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
    }

    // MARK: - Start Streaming Section

    private var startStreamingSection: some View {
        VStack(spacing: DesignTokens.Spacing.space3) {
            Button {
                Task {
                    if let rtmpInfo = await viewModel.setupLiveStream() {
                        // Set the YouTube VM reference on camera VM for lifecycle management
                        cameraViewModel.youTubeStreamingViewModel = viewModel
                        // Auto-connect: pass RTMP URL and stream key to existing StreamingService
                        cameraViewModel.startStreaming(url: rtmpInfo.rtmpURL, streamKey: rtmpInfo.streamKey, isYouTubeAPI: true)
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.space2) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: DesignTokens.Typography.base))
                    }
                    Text(viewModel.isLoading ? "配信準備中..." : "YouTube配信を開始")
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.space4)
                .background(viewModel.isLoading ? DesignTokens.Colors.textTertiary : Color(hex: 0xFF0000))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal, DesignTokens.Spacing.space2)
            .accessibilityIdentifier("startYouTubeStreamingButton")
            .accessibilityLabel("YouTube配信を開始")

            // Info footer
            HStack(alignment: .top, spacing: DesignTokens.Spacing.space2) {
                Image(systemName: "info.circle")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text("YouTube APIで自動的に配信枠を作成し、RTMP接続を行います。手動でのURL・キー入力は不要です。")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .lineSpacing(3)
            }
            .padding(.horizontal, DesignTokens.Spacing.space1)
        }
    }

    // MARK: - Stream Health Section

    private var streamHealthSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "配信状態")

            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.space3) {
                    Circle()
                        .fill(streamHealthColor)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ストリームヘルス")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        Text(streamHealthDisplayText)
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                    }

                    Spacer()

                    // Lifecycle status badge
                    Text(viewModel.broadcastStatus.displayName)
                        .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignTokens.Spacing.space3)
                        .padding(.vertical, DesignTokens.Spacing.space1)
                        .background(broadcastStatusColor)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("broadcastStatusBadge")
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)

                // Warning banner for bad health
                if viewModel.streamHealth == .bad {
                    Divider()
                        .background(DesignTokens.Colors.border)

                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.warning)
                        Text("配信品質が低下しています")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.space4)
                    .padding(.vertical, DesignTokens.Spacing.space3)
                    .background(DesignTokens.Colors.warning.opacity(0.1))
                    .accessibilityIdentifier("streamHealthBadWarning")
                }

                // Warning banner for noData timeout
                if viewModel.showNoDataWarning {
                    Divider()
                        .background(DesignTokens.Colors.border)

                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.warning)
                        Text("接続に問題がある可能性があります。ネットワーク状態を確認してください。")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.space4)
                    .padding(.vertical, DesignTokens.Spacing.space3)
                    .background(DesignTokens.Colors.warning.opacity(0.1))
                    .accessibilityIdentifier("streamNoDataWarning")
                }

                // Transitioning indicator
                if viewModel.isTransitioning {
                    Divider()
                        .background(DesignTokens.Colors.border)

                    HStack(spacing: DesignTokens.Spacing.space2) {
                        ProgressView()
                            .tint(DesignTokens.Colors.textSecondary)
                            .scaleEffect(0.8)
                        Text("配信ステータスを遷移中...")
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.space4)
                    .padding(.vertical, DesignTokens.Spacing.space3)
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
        .accessibilityIdentifier("streamHealthSection")
    }

    // MARK: - Broadcast Status Section

    private var broadcastStatusSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "配信情報")

            VStack(spacing: 0) {
                // Current title
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("タイトル")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text(viewModel.broadcastTitle)
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)

                Divider()
                    .background(DesignTokens.Colors.border)

                // Current description
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("説明文")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text(viewModel.broadcastDescription.isEmpty ? "(なし)" : viewModel.broadcastDescription)
                            .font(.system(size: DesignTokens.Typography.sm))
                            .foregroundStyle(
                                viewModel.broadcastDescription.isEmpty
                                    ? DesignTokens.Colors.textTertiary
                                    : DesignTokens.Colors.textPrimary
                            )
                            .lineLimit(3)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space3)
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
    }

    // MARK: - Metadata Editor Section

    private var metadataEditorSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            sectionHeader(title: "メタデータ編集")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
                    // Editable title
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        Text("タイトル")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        TextField("配信タイトル", text: $editingTitle)
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
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                            .accessibilityIdentifier("editBroadcastTitleField")
                    }

                    // Editable description
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                        Text("説明文")
                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        TextField("配信の説明", text: $editingDescription)
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
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                            .accessibilityIdentifier("editBroadcastDescriptionField")
                    }

                    // Save button
                    Button {
                        Task {
                            await viewModel.updateMetadata(
                                title: editingTitle.isEmpty ? viewModel.broadcastTitle : editingTitle,
                                description: editingDescription
                            )
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            if viewModel.isUpdatingMetadata {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isUpdatingMetadata ? "更新中..." : "メタデータを更新")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.space3)
                        .background(viewModel.isUpdatingMetadata ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                    }
                    .disabled(viewModel.isUpdatingMetadata)
                    .accessibilityIdentifier("updateMetadataButton")
                    .accessibilityLabel("メタデータを更新")

                    // Success indicator
                    if viewModel.metadataUpdateSuccess {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: DesignTokens.Typography.sm))
                                .foregroundStyle(DesignTokens.Colors.success)
                            Text("メタデータを更新しました")
                                .font(.system(size: DesignTokens.Typography.xs))
                                .foregroundStyle(DesignTokens.Colors.success)
                        }
                        .accessibilityIdentifier("metadataUpdateSuccess")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.vertical, DesignTokens.Spacing.space4)
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
        .onAppear {
            editingTitle = viewModel.broadcastTitle
            editingDescription = viewModel.broadcastDescription
        }
        .accessibilityIdentifier("metadataEditorSection")
    }

    // MARK: - Re-auth Prompt

    private var reAuthPrompt: some View {
        VStack(spacing: DesignTokens.Spacing.space3) {
            HStack(spacing: DesignTokens.Spacing.space2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DesignTokens.Typography.base))
                    .foregroundStyle(DesignTokens.Colors.warning)
                Text("認証の有効期限が切れました。再ログインしてください。")
                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.signIn() }
            } label: {
                Text("再ログイン")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.space3)
                    .background(DesignTokens.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            }
            .accessibilityIdentifier("reAuthButton")
        }
        .padding(DesignTokens.Spacing.space4)
        .background(DesignTokens.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .accessibilityIdentifier("reAuthPrompt")
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
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
        .accessibilityIdentifier("youTubeErrorMessage")
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

    // MARK: - Helper Properties

    private var streamHealthColor: Color {
        switch viewModel.streamHealth {
        case .good:
            return DesignTokens.Colors.success
        case .ok:
            return DesignTokens.Colors.success
        case .bad:
            return DesignTokens.Colors.warning
        case .noData:
            return DesignTokens.Colors.textTertiary
        }
    }

    private var streamHealthDisplayText: String {
        switch viewModel.streamHealth {
        case .good:
            return "配信品質: 良好"
        case .ok:
            return "配信品質: 正常"
        case .bad:
            return "配信品質: 低下"
        case .noData:
            return "データ取得中..."
        }
    }

    private var broadcastStatusColor: Color {
        switch viewModel.broadcastStatus {
        case .live:
            return Color(hex: 0xFF0000)
        case .testing:
            return DesignTokens.Colors.warning
        case .complete:
            return DesignTokens.Colors.textTertiary
        default:
            return DesignTokens.Colors.accent
        }
    }
}
