import SwiftUI

/// View for managing streaming destinations.
/// Shows a list of saved destinations and allows adding, deleting, and selecting.
struct StreamingSettingsView: View {

    @ObservedObject var viewModel: StreamingSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.space6) {

                // MARK: - Destinations List

                sectionHeader(title: "保存済みの配信先")

                if viewModel.destinations.isEmpty {
                    emptyStateView
                } else {
                    destinationsList
                }

                // MARK: - Add Destination Button

                VStack(spacing: 0) {
                    Button {
                        viewModel.startAddingDestination()
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.space3) {
                            ZStack {
                                Circle()
                                    .fill(DesignTokens.Colors.surface)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                                    )

                                Image(systemName: "plus")
                                    .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                                    .foregroundStyle(DesignTokens.Colors.accent)
                            }

                            Text("配信先を追加")
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
                }
                .background(DesignTokens.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                .accessibilityIdentifier("addDestinationButton")
                .accessibilityLabel("配信先を追加")

                // MARK: - Info Footer

                HStack(alignment: .top, spacing: DesignTokens.Spacing.space2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: DesignTokens.Typography.xs))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                    Text("配信先を選択して、カメラ画面から配信を開始できます。ストリームキーは端末内にのみ保存されます。")
                        .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.normal))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineSpacing(3)
                }
                .padding(.horizontal, DesignTokens.Spacing.space1)
                .padding(.top, DesignTokens.Spacing.space2)
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.top, DesignTokens.Spacing.space4)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }
        .background(DesignTokens.Colors.primary)
        .navigationTitle("配信設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignTokens.Colors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $viewModel.isAddingDestination) {
            AddStreamingDestinationView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadDestinations()
        }
        .accessibilityIdentifier("streamingSettingsView")
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.space5) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Colors.borderStrong, lineWidth: 1)
                    .frame(width: 72, height: 72)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            VStack(spacing: DesignTokens.Spacing.space2) {
                Text("配信先が登録されていません")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Text("「配信先を追加」から配信先を設定してください")
                    .font(.system(size: DesignTokens.Typography.sm))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.space12)
        .background(DesignTokens.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .accessibilityIdentifier("emptyDestinationsState")
    }

    // MARK: - Destinations List

    private var destinationsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, destination in
                DestinationRow(
                    destination: destination,
                    isSelected: viewModel.isSelected(destination),
                    onTap: {
                        viewModel.startEditingDestination(destination)
                    }
                )

                if index < viewModel.destinations.count - 1 {
                    Divider()
                        .background(DesignTokens.Colors.border)
                        .padding(.leading, DesignTokens.Spacing.space4 + 44 + DesignTokens.Spacing.space3)
                }
            }
        }
        .background(DesignTokens.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }
}

// MARK: - Destination Row

/// A row displaying a saved streaming destination. Tap to edit.
struct DestinationRow: View {
    let destination: StreamingDestination
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignTokens.Spacing.space3) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignTokens.Colors.accent.opacity(0.1) : DesignTokens.Colors.surface)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? DesignTokens.Colors.accent.opacity(0.25) : DesignTokens.Colors.border,
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )

                    Image(systemName: destination.platform.iconName)
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                        .foregroundStyle(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.space1) {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Text(destination.name)
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(1)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: DesignTokens.Typography.sm))
                                .foregroundStyle(DesignTokens.Colors.accent)
                        }
                    }

                    Text(destination.platform.displayName)
                        .font(.system(size: DesignTokens.Typography.sm))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.space4)
            .padding(.vertical, DesignTokens.Spacing.space3)
        }
        .accessibilityIdentifier("destinationRow_\(destination.id.uuidString)")
    }
}
