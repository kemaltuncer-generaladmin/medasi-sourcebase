import SwiftUI
import SourceBaseBackend

/// Reusable "save to section + export to branded PDF + share" control. Dropped
/// into every study surface so all output types share the same save + export
/// behaviour.
struct SBPdfExportControls: View {
    let output: GeneratedOutput

    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportMessage: String?
    @State private var showSavePicker = false

    var body: some View {
        SBCard(radius: 18, borderColor: SBOutputStyle.accent(for: output.kind).opacity(0.16)) {
            VStack(alignment: .leading, spacing: SBSpacing.md) {
                HStack(spacing: SBSpacing.sm) {
                    Image(systemName: "doc.richtext.fill")
                        .sbScaledFont(size: 18, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(SBOutputStyle.accent(for: output.kind))
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Premium PDF")
                            .font(SBTypography.titleSmall)
                            .foregroundStyle(SBColors.navy)
                        Text("Tablet ve çıktı için düzenlenmiş çalışma paketi.")
                            .font(SBTypography.caption)
                            .foregroundStyle(SBColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SBSpacing.sm) {
                        saveButton
                        exportButton
                    }
                    VStack(spacing: SBSpacing.sm) {
                        saveButton
                        exportButton
                    }
                }

                if isExporting {
                    ProgressView(value: 0.72)
                        .tint(SBOutputStyle.accent(for: output.kind))
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        HStack(spacing: SBSpacing.sm) {
                            Image(systemName: "paperplane.fill")
                            Text("PDF paylaş veya yazdır")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(SBTypography.labelMedium)
                        .foregroundStyle(SBOutputStyle.accent(for: output.kind))
                        .padding(SBSpacing.md)
                        .background(SBOutputStyle.accent(for: output.kind).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }

                if let exportMessage {
                    SBInlineError(message: exportMessage, isWarning: true)
                }
            }
        }
        .sheet(isPresented: $showSavePicker) {
            SaveToSectionSheet(output: output)
        }
    }

    private var saveButton: some View {
        SBButton("Bölüme kaydet", icon: "folder.badge.plus", variant: .secondary, fullWidth: true) {
            showSavePicker = true
        }
    }

    private var exportButton: some View {
        SBButton(
            isExporting ? "Hazırlanıyor" : "PDF oluştur",
            icon: isExporting ? "hourglass" : "square.and.arrow.up",
            fullWidth: true
        ) {
            prepareExport()
        }
        .disabled(isExporting)
    }

    private func prepareExport() {
        isExporting = true
        exportMessage = nil
        Task {
            do {
                let url = try await SBStudyExportService.exportPDF(for: output)
                exportURL = url
            } catch {
                exportMessage = "PDF hazırlanamadı. Lütfen tekrar dene."
            }
            isExporting = false
        }
    }
}

/// Course → section picker that saves the output as a first-class section item.
private struct SaveToSectionSheet: View {
    let output: GeneratedOutput

    @Environment(SourceBaseWorkspaceStore.self) private var workspaceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                let courses = workspaceStore.workspace.courses
                if courses.isEmpty {
                    SBEmptyState(
                        icon: "folder",
                        title: "Henüz ders yok",
                        message: "Önce Drive'da bir ders ve bölüm oluştur, sonra çıktıyı oraya kaydet."
                    )
                    .padding(SBSpacing.lg)
                } else {
                    List {
                        ForEach(courses) { course in
                            Section(course.title) {
                                if course.sections.isEmpty {
                                    Text("Bu derste bölüm yok")
                                        .font(SBTypography.bodySmall)
                                        .foregroundStyle(SBColors.muted)
                                } else {
                                    ForEach(course.sections) { section in
                                        Button {
                                            save(courseId: course.id, sectionId: section.id)
                                        } label: {
                                            HStack(spacing: SBSpacing.sm) {
                                                Image(systemName: "tray.full")
                                                    .foregroundStyle(SBColors.blue)
                                                Text(section.title)
                                                    .font(SBTypography.bodyMedium)
                                                    .foregroundStyle(SBColors.navy)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(SBColors.softText)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bölüme Kaydet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task { await workspaceStore.loadWorkspace() }
        }
    }

    private func save(courseId: String, sectionId: String) {
        Task {
            await workspaceStore.saveOutput(output.id, courseId: courseId, sectionId: sectionId)
            dismiss()
        }
    }
}
