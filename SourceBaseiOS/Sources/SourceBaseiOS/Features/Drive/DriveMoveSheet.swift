import SwiftUI
import SourceBaseBackend

struct DriveMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore

    let fileCount: Int
    let currentSectionId: String?
    let onMove: (DriveDestination) -> Void

    @State private var selectedDestination: DriveDestination?

    private var destinations: [DriveDestination] {
        workspaceStore.availableDestinations
    }

    private var canMove: Bool {
        guard let selectedDestination else { return false }
        return selectedDestination.sectionId != currentSectionId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SBSpacing.lg) {
                    SBPageHeader(
                        title: "Hedef seç",
                        subtitle: "\(fileCount) dosya taşınacak ders ve bölümü seç."
                    )

                    if destinations.isEmpty {
                        SBEmptyState(
                            icon: "folder.badge.plus",
                            title: "Taşıma hedefi yok",
                            message: "Dosyaları taşımak için en az bir ders ve bölüm gerekir.",
                            actionLabel: "Bölüm oluştur",
                            onAction: {
                                Task {
                                    await workspaceStore.createSection()
                                    selectedDestination = workspaceStore.preferredUploadDestination
                                }
                            }
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: SBSpacing.sm)], spacing: SBSpacing.sm) {
                            ForEach(destinations, id: \.sectionId) { destination in
                                destinationButton(destination)
                            }
                        }
                    }

                    SBButton(
                        "Taşı",
                        icon: "folder.badge.gearshape",
                        variant: .primary,
                        size: .large,
                        fullWidth: true
                    ) {
                        guard let selectedDestination, canMove else {
                            workspaceStore.toast("Farklı bir hedef bölüm seç.")
                            return
                        }
                        onMove(selectedDestination)
                        dismiss()
                    }
                    .disabled(!canMove)
                }
                .padding(SBSpacing.lg)
            }
            .sbPageBackground()
            .navigationTitle("Taşı")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selectedDestination = destinations.first { $0.sectionId != currentSectionId }
                ?? destinations.first
        }
    }

    private func destinationButton(_ destination: DriveDestination) -> some View {
        let isSelected = selectedDestination == destination
        let isCurrent = destination.sectionId == currentSectionId
        return Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: SBSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "folder")
                    .sbScaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(isSelected ? SBColors.blue : SBColors.muted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.courseTitle)
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBColors.navy)
                        .lineLimit(1)
                    Text(isCurrent ? "\(destination.sectionTitle) • mevcut" : destination.sectionTitle)
                        .font(SBTypography.caption)
                        .foregroundStyle(isCurrent ? SBColors.orange : SBColors.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(SBSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(isSelected ? SBColors.selectedBlue : SBColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? SBColors.blue.opacity(0.24) : SBColors.softLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(destination.courseTitle), \(destination.sectionTitle)")
        .accessibilityValue(isSelected ? "Seçili" : isCurrent ? "Mevcut hedef" : "")
    }
}
