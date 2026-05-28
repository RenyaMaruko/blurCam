import SwiftUI

/// View for adding a new streaming destination.
/// Provides platform presets (YouTube Live, Twitch, Custom RTMP),
/// RTMP URL input, and stream key input with validation.
struct AddStreamingDestinationView: View {

    @ObservedObject var viewModel: StreamingSettingsViewModel
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.space6) {

                    // MARK: - Platform Selection

                    platformSectionHeader(title: "プラットフォーム")

                    VStack(spacing: 0) {
                        ForEach(Array(StreamingPlatform.allCases.enumerated()), id: \.element.id) { index, platform in
                            Button {
                                withAnimation(.easeInOut(duration: DesignTokens.Motion.fast)) {
                                    viewModel.selectedPlatform = platform
                                }
                            } label: {
                                HStack(spacing: DesignTokens.Spacing.space3) {
                                    Image(systemName: platform.iconName)
                                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(
                                            viewModel.selectedPlatform == platform
                                                ? DesignTokens.Colors.accent
                                                : DesignTokens.Colors.textSecondary
                                        )
                                        .frame(width: 28)

                                    Text(platform.displayName)
                                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                                    Spacer()

                                    if viewModel.selectedPlatform == platform {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.semibold))
                                            .foregroundStyle(DesignTokens.Colors.accent)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, DesignTokens.Spacing.space4)
                                .padding(.vertical, DesignTokens.Spacing.space3)
                                .background(
                                    viewModel.selectedPlatform == platform
                                        ? DesignTokens.Colors.accent.opacity(0.06)
                                        : Color.clear
                                )
                            }
                            .accessibilityIdentifier("platformOption_\(platform.rawValue)")
                            .accessibilityLabel(platform.displayName)

                            if index < StreamingPlatform.allCases.count - 1 {
                                Divider()
                                    .background(DesignTokens.Colors.border)
                                    .padding(.leading, DesignTokens.Spacing.space4 + 28 + DesignTokens.Spacing.space3)
                            }
                        }
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))

                    // MARK: - Connection Details

                    platformSectionHeader(title: "接続設定")

                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space5) {
                            // Name input (optional)
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                                HStack(spacing: DesignTokens.Spacing.space2) {
                                    Image(systemName: "tag")
                                        .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    Text("名前（任意）")
                                        .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                }

                                TextField(viewModel.selectedPlatform.displayName, text: $viewModel.formName)
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
                                    .accessibilityIdentifier("destinationNameField")
                            }

                            Divider()
                                .background(DesignTokens.Colors.border)

                            // RTMP URL input
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                                HStack(spacing: DesignTokens.Spacing.space2) {
                                    Image(systemName: "link")
                                        .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    Text("RTMP URL")
                                        .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                }

                                TextField("rtmp://live.example.com/app", text: $viewModel.formRTMPURL)
                                    .font(.system(size: DesignTokens.Typography.sm))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .disabled(viewModel.selectedPlatform != .custom)
                                    .opacity(viewModel.selectedPlatform != .custom ? 0.5 : 1.0)
                                    .padding(.horizontal, DesignTokens.Spacing.space3)
                                    .padding(.vertical, DesignTokens.Spacing.space3)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                            .fill(DesignTokens.Colors.primary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                            .stroke(
                                                viewModel.formValidationError == .emptyURL || viewModel.formValidationError == .invalidURLFormat
                                                    ? DesignTokens.Colors.error
                                                    : DesignTokens.Colors.border,
                                                lineWidth: 1
                                            )
                                    )
                                    .accessibilityIdentifier("destinationRTMPURLField")
                                    .onChange(of: viewModel.formRTMPURL) { _, _ in
                                        viewModel.formValidationError = nil
                                    }

                                if viewModel.selectedPlatform != .custom {
                                    HStack(spacing: DesignTokens.Spacing.space1) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: DesignTokens.Typography.xs - 1))
                                        Text("プリセットURLが自動入力されています")
                                            .font(.system(size: DesignTokens.Typography.xs))
                                    }
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                }
                            }

                            Divider()
                                .background(DesignTokens.Colors.border)

                            // Stream Key input
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
                                HStack(spacing: DesignTokens.Spacing.space2) {
                                    Image(systemName: "key")
                                        .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    Text("ストリームキー")
                                        .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                }

                                TextField("ストリームキーを入力", text: $viewModel.formStreamKey)
                                    .font(.system(size: DesignTokens.Typography.sm))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .accessibilityIdentifier("destinationStreamKeyTextField")
                                .padding(.horizontal, DesignTokens.Spacing.space3)
                                .padding(.vertical, DesignTokens.Spacing.space3)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                        .fill(DesignTokens.Colors.primary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                        .stroke(
                                            viewModel.formValidationError == .emptyStreamKey
                                                ? DesignTokens.Colors.error
                                                : DesignTokens.Colors.border,
                                            lineWidth: 1
                                        )
                                )
                                .accessibilityIdentifier("destinationStreamKeyField")
                                .onChange(of: viewModel.formStreamKey) { _, _ in
                                    viewModel.formValidationError = nil
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.space4)
                        .padding(.vertical, DesignTokens.Spacing.space4)
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))

                    // MARK: - Validation Error

                    if let error = viewModel.formValidationError {
                        HStack(spacing: DesignTokens.Spacing.space2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: DesignTokens.Typography.sm))
                                .foregroundStyle(DesignTokens.Colors.error)
                            Text(error.errorDescription ?? "")
                                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.error)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.space1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityIdentifier("validationErrorMessage")
                    }

                    // MARK: - Save Button

                    Button {
                        viewModel.saveDestination()
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
                    .accessibilityIdentifier("saveDestinationButton")
                    .accessibilityLabel("配信先を保存")

                    // MARK: - Delete Button (edit mode only)

                    if viewModel.editingDestination != nil {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("この配信先を削除")
                                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                .foregroundStyle(DesignTokens.Colors.error)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.Spacing.space4)
                        }
                        .padding(.top, DesignTokens.Spacing.space2)
                        .accessibilityIdentifier("deleteDestinationButton")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.top, DesignTokens.Spacing.space4)
                .padding(.bottom, DesignTokens.Spacing.space8)
            }
            .background(DesignTokens.Colors.primary)
            .navigationTitle(viewModel.editingDestination != nil ? "配信先を編集" : "配信先を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.Colors.backgroundSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isAddingDestination = false
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .accessibilityIdentifier("cancelAddDestinationButton")
                }
            }
        }
        .alert("配信先の削除", isPresented: $showDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let dest = viewModel.editingDestination {
                    viewModel.requestDeleteDestination(dest)
                    viewModel.confirmDeleteDestination()
                    viewModel.isAddingDestination = false
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この配信先を削除しますか？")
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("addStreamingDestinationView")
    }

    // MARK: - Section Header

    private func platformSectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.normal))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.space1)
    }
}
