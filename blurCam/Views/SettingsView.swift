import SwiftUI

/// Settings screen for managing registered faces and blur intensity.
/// Presented as a sheet from the camera preview screen.
/// Styled to match iOS Settings dark appearance with design tokens.
struct SettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.space6) {
                    // MARK: - Registered Faces Section
                    settingsSectionHeader(title: "登録済みの顔", identifier: "registeredFacesHeader")

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.registeredFaces.enumerated()), id: \.element.id) { index, face in
                            FaceListRow(
                                face: face,
                                onDelete: {
                                    viewModel.requestDeleteFace(face)
                                }
                            )

                            if index < viewModel.registeredFaces.count - 1 {
                                Divider()
                                    .background(DesignTokens.Colors.border)
                                    .padding(.leading, 50 + DesignTokens.Spacing.space3 + DesignTokens.Spacing.space4)
                            }
                        }

                        if !viewModel.registeredFaces.isEmpty {
                            Divider()
                                .background(DesignTokens.Colors.border)
                                .padding(.leading, DesignTokens.Spacing.space4)
                        }

                        // Add face button
                        Button {
                            viewModel.startAddingFace()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.space3) {
                                ZStack {
                                    Circle()
                                        .fill(DesignTokens.Colors.surface)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                                        )

                                    Image(systemName: "plus")
                                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                                        .foregroundStyle(DesignTokens.Colors.accent)
                                }

                                Text("顔を追加")
                                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                    .foregroundStyle(DesignTokens.Colors.accent)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.space4)
                            .padding(.vertical, DesignTokens.Spacing.space3)
                        }
                        .accessibilityIdentifier("addFaceButton")
                        .accessibilityLabel("顔を追加")
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))

                    // MARK: - Blur Intensity Section
                    settingsSectionHeader(title: "ブラー設定", identifier: "blurSettingsHeader")

                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
                            HStack {
                                Text("ブラー強度")
                                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Spacer()

                                Text(viewModel.blurIntensity.displayName)
                                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .padding(.horizontal, DesignTokens.Spacing.space3)
                                    .padding(.vertical, DesignTokens.Spacing.space1)
                                    .background(
                                        Capsule()
                                            .fill(DesignTokens.Colors.surface)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                                    )
                                    .accessibilityIdentifier("blurIntensityLabel")
                            }

                            // Stepped indicator
                            blurIntensityControl
                        }
                        .padding(.horizontal, DesignTokens.Spacing.space4)
                        .padding(.vertical, DesignTokens.Spacing.space4)
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))

                    // MARK: - Privacy Footer
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: DesignTokens.Typography.xs))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        Text("顔データは端末内にのみ保存されます")
                            .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.normal))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DesignTokens.Spacing.space2)
                }
                .padding(.horizontal, DesignTokens.Spacing.space4)
                .padding(.top, DesignTokens.Spacing.space4)
                .padding(.bottom, DesignTokens.Spacing.space8)
            }
            .background(DesignTokens.Colors.primary)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.Colors.backgroundSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("完了")
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .accessibilityIdentifier("settingsDoneButton")
                    .accessibilityLabel("設定を閉じる")
                }
            }
            .alert("顔データの削除", isPresented: $viewModel.showDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    viewModel.confirmDeleteFace()
                }
                .accessibilityIdentifier("confirmDeleteButton")

                Button("キャンセル", role: .cancel) {
                    viewModel.cancelDeleteFace()
                }
                .accessibilityIdentifier("cancelDeleteButton")
            } message: {
                Text("この顔データを削除しますか？削除すると、この人物はブラー対象になります。")
            }
            .sheet(isPresented: $viewModel.isAddingFace) {
                FaceAdditionFlowView(
                    onFaceAdded: {
                        viewModel.onFaceAdded()
                    },
                    onCancel: {
                        viewModel.isAddingFace = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("settingsView")
    }

    // MARK: - Section Header

    private func settingsSectionHeader(title: String, identifier: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.normal))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)
                .accessibilityIdentifier(identifier)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.space1)
    }

    // MARK: - Blur Intensity Control

    private var blurIntensityControl: some View {
        VStack(spacing: DesignTokens.Spacing.space2) {
            // Slider with min/max icons
            HStack(spacing: DesignTokens.Spacing.space3) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: DesignTokens.Typography.sm))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Slider(
                    value: Binding(
                        get: { viewModel.blurSliderValue },
                        set: { viewModel.blurSliderValue = $0 }
                    ),
                    in: 0...1,
                    step: 0.5
                )
                .tint(DesignTokens.Colors.textPrimary)
                .accessibilityIdentifier("blurIntensitySlider")
                .accessibilityLabel("ブラー強度")
                .accessibilityValue(viewModel.blurIntensity.displayName)

                Image(systemName: "circle.fill")
                    .font(.system(size: DesignTokens.Typography.sm))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            // Step labels beneath the slider
            HStack {
                Text("弱")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(viewModel.blurIntensity == .low ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
                Spacer()
                Text("中")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(viewModel.blurIntensity == .medium ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
                Spacer()
                Text("強")
                    .font(.system(size: DesignTokens.Typography.xs))
                    .foregroundStyle(viewModel.blurIntensity == .high ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.space8)
        }
    }
}

// MARK: - Face List Row

/// A row in the registered faces list displaying a face thumbnail and delete button.
/// Styled with dark theme and subtle borders matching iOS Settings appearance.
struct FaceListRow: View {
    let face: FaceGroupEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.space3) {
            // Face thumbnail
            faceThumbnail

            // Face info
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space1) {
                Text("登録済みの顔")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("\(formattedDate) · \(face.photoCount)枚")
                    .font(.system(size: DesignTokens.Typography.sm))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            // Delete button -- minimal, icon only
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: DesignTokens.Typography.xl))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityIdentifier("deleteFaceButton_\(face.id.uuidString)")
            .accessibilityLabel("顔を削除")
        }
        .padding(.horizontal, DesignTokens.Spacing.space4)
        .padding(.vertical, DesignTokens.Spacing.space3)
        .accessibilityIdentifier("faceRow_\(face.id.uuidString)")
    }

    private var faceThumbnail: some View {
        Group {
            if let imageData = face.thumbnailData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DesignTokens.Colors.borderStrong, lineWidth: 1.5)
                    )
            } else {
                Circle()
                    .fill(DesignTokens.Colors.surface)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: DesignTokens.Typography.xl))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    )
                    .overlay(
                        Circle()
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .accessibilityIdentifier("faceThumbnail_\(face.id.uuidString)")
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: face.registeredAt)
    }
}
