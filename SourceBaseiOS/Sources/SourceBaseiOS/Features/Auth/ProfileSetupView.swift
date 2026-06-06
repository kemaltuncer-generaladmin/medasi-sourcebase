import SwiftUI
import SourceBaseBackend

struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var faculty = ""
    @State private var department = "Tıp"
    @State private var localError: String?
    @FocusState private var isFacultyFocused: Bool

    private let departments = ["Tıp", "Diş Hekimliği", "Hemşirelik"]

    private var session: SessionStore { appState.session }
    private var router: AppRouter { appState.router }

    private var canSubmit: Bool {
        !faculty.trimmingCharacters(in: .whitespaces).isEmpty && !session.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SBSpacing.xl) {
                headerSection
                formSection
                messageSection
                actionButton
            }
            .padding(SBSpacing.xl)
            .sbReadableWidth(720)
        }
        .sbPageBackground()
        .sbBackButton(isVisible: router.canPop) {
            router.pop()
        }
        .onAppear {
            loadExistingProfile()
        }
        .onChange(of: session.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn && !session.needsProfileSetup {
                finishEditing()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Profilini tamamla")
                .font(SBTypography.display2)
                .foregroundStyle(SBColors.navy)

            Text("Hesap ve çalışma alanı bilgilerini düzenle.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: SBSpacing.lg) {
            // Faculty
            VStack(alignment: .leading, spacing: SBSpacing.sm) {
                Text("Fakülte / Üniversite")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)

                HStack(spacing: SBSpacing.md) {
                    Image(systemName: "building.columns")
                        .sbScaledFont(size: 18, weight: .medium)
                        .foregroundStyle(SBColors.blue)
                        .frame(width: 24)

                    TextField("Örn: İstanbul Üniversitesi", text: $faculty)
                        .font(SBTypography.bodyMedium)
                        .foregroundStyle(SBColors.navy)
                        .focused($isFacultyFocused)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .submitLabel(.done)
                        .accessibilityLabel("Fakülte veya üniversite")
                }
                .padding(.horizontal, SBSpacing.lg)
                .frame(height: 52)
                .background(SBColors.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFacultyFocused ? SBColors.blue : SBColors.line, lineWidth: isFacultyFocused ? 1.5 : 1)
                )
                .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)

                universitySuggestions
            }

            // Department
            departmentSection
        }
    }

    // MARK: - University Suggestions

    private var universitySuggestions: some View {
        let trimmed = faculty.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = UniversityCatalog.matches(faculty)
        let exactlySelected = UniversityCatalog.all.contains(faculty)

        return Group {
            if exactlySelected {
                EmptyView() // already chosen — hide list
            } else if !trimmed.isEmpty && matches.isEmpty {
                HStack(spacing: SBSpacing.sm) {
                    Image(systemName: "info.circle")
                        .sbScaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(SBColors.muted)
                    Text("Üniversite bulunamadı. Yazdığın şekilde kaydedilecek.")
                        .font(SBTypography.bodySmall)
                        .foregroundStyle(SBColors.muted)
                    Spacer()
                }
                .padding(.horizontal, SBSpacing.md)
                .padding(.vertical, SBSpacing.sm)
                .background(SBColors.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(SBColors.softLine, lineWidth: 1)
                )
            } else {
                VStack(spacing: SBSpacing.xs) {
                    ForEach(Array(matches.prefix(8)), id: \.self) { university in
                        universitySuggestionRow(university)
                    }
                }
            }
        }
    }

    private func universitySuggestionRow(_ university: String) -> some View {
        let isSelected = faculty == university
        return Button {
            faculty = university
            isFacultyFocused = false
        } label: {
            HStack(spacing: SBSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "building.columns")
                    .sbScaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(isSelected ? SBColors.green : SBColors.blue)
                Text(university)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.navy)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, SBSpacing.md)
            .padding(.vertical, SBSpacing.sm)
            .background(isSelected ? SBColors.greenBg : SBColors.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? SBColors.green.opacity(0.35) : SBColors.softLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(university)
        .accessibilityHint("Üniversite olarak seç")
    }

    // MARK: - Department

    private var departmentSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.sm) {
                Text("Bölüm")
                    .font(SBTypography.labelMedium)
                    .foregroundStyle(SBColors.navy)

                HStack(spacing: SBSpacing.md) {
                    Image(systemName: "graduationcap")
                        .sbScaledFont(size: 18, weight: .medium)
                        .foregroundStyle(SBColors.blue)
                        .frame(width: 24)

                    Picker("Bölüm", selection: $department) {
                        ForEach(departments, id: \.self) { dept in
                            Text(dept).tag(dept)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(SBColors.navy)
                }
                .padding(.horizontal, SBSpacing.lg)
                .frame(height: 52)
                .background(SBColors.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SBColors.line, lineWidth: 1)
                )
                .shadow(color: SBColors.navy.opacity(0.05), radius: 8, x: 0, y: 4)
            }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messageSection: some View {
        if let error = localError ?? session.errorMessage {
            SBInlineError(message: error)
        }
        if let success = session.successMessage {
            HStack(spacing: SBSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SBColors.green)
                Text(success)
                    .font(SBTypography.bodySmall)
                    .foregroundStyle(SBColors.green)
            }
            .padding(SBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SBColors.greenBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Action

    private var actionButton: some View {
        SBButton(
            session.isLoading ? "Kaydediliyor..." : "Devam Et",
            icon: "arrow.right",
            variant: .primary,
            size: .large,
            isLoading: session.isLoading,
            fullWidth: true,
            action: completeProfile
        )
        .disabled(!canSubmit)
    }

    // MARK: - Actions

    private func loadExistingProfile() {
        if let user = session.currentUser {
            let metadata = user.userMetadata
            if let savedFaculty = metadata["sourcebase_faculty"]?.stringValue, !savedFaculty.isEmpty {
                faculty = savedFaculty
            }
            if let savedDept = metadata["sourcebase_department"]?.stringValue,
               departments.contains(savedDept) {
                department = savedDept
            }
        }
    }

    private func completeProfile() {
        guard canSubmit else { return }

        if faculty.trimmingCharacters(in: .whitespaces).isEmpty {
            localError = "Üniversite bilgisini seçmelisin."
            return
        }

        localError = nil
        session.clearMessages()

        Task {
            await session.updateProfile(faculty: faculty, department: department)
        }
    }

    private func finishEditing() {
        if router.canPop {
            router.pop()
        } else {
            router.reset(to: .drive)
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AppState.shared)
}
