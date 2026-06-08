import SwiftUI
import SourceBaseBackend

struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var faculty = ""
    @State private var department = "Tıp"
    @State private var classYear = "1. sınıf"
    @State private var goal = "Dönem sınavları"
    @State private var localError: String?
    @FocusState private var isFacultyFocused: Bool

    // SourceBase covers all health-sciences disciplines — output is specialized per field.
    private let departments = ["Veterinerlik", "Tıp", "Diş Hekimliği", "Hemşirelik", "Ebelik"]
    private let classYears = ["1. sınıf", "2. sınıf", "3. sınıf", "4. sınıf", "5. sınıf", "6. sınıf", "Mezun"]

    /// Exam/goal options tailored to the chosen discipline.
    private func goals(for department: String) -> [String] {
        switch department {
        case "Tıp": return ["Dönem sınavları", "TUS", "USMLE", "Genel tekrar"]
        case "Diş Hekimliği": return ["Dönem sınavları", "DUS", "Genel tekrar"]
        case "Veterinerlik": return ["Dönem sınavları", "Uzmanlık/alan sınavı", "Saha pratiği", "Genel tekrar"]
        case "Hemşirelik", "Ebelik": return ["Dönem sınavları", "KPSS/atama", "İntibak", "Klinik pratik", "Genel tekrar"]
        default: return ["Dönem sınavları", "Genel tekrar"]
        }
    }

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
        .onChange(of: department) { _, newDept in
            if !goals(for: newDept).contains(goal) {
                goal = goals(for: newDept).first ?? "Genel tekrar"
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.md) {
            Text("Kurulum")
                .font(SBTypography.labelSmall)
                .foregroundStyle(SBColors.blue)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(SBColors.softBlue, in: Capsule())

            Text("Profilini tamamla")
                .font(SBTypography.display2)
                .foregroundStyle(SBColors.navy)

            Text("Bölümün, sınıfın ve hedefin; üretilen tüm çalışma içeriğinin terminolojisini, derinliğini ve odağını belirler.")
                .font(SBTypography.bodyMedium)
                .foregroundStyle(SBColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func disciplineIcon(_ discipline: String) -> String {
        switch discipline {
        case "Veterinerlik": return "pawprint.fill"
        case "Tıp": return "stethoscope"
        case "Diş Hekimliği": return "mouth.fill"
        case "Hemşirelik": return "cross.case.fill"
        case "Ebelik": return "figure.and.child.holdinghands"
        default: return "graduationcap.fill"
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: SBSpacing.xl) {
            SBFieldSection(title: "Fakülte / Üniversite", icon: "building.columns") {
                facultyField
                universitySuggestions
            }

            // Discipline — tailors AI terminology/scope per field
            SBFieldSection(title: "Bölüm", icon: "graduationcap") {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: SBSpacing.md), GridItem(.flexible(), spacing: SBSpacing.md)],
                    spacing: SBSpacing.md
                ) {
                    ForEach(departments, id: \.self) { discipline in
                        SBDisciplineCard(
                            title: discipline,
                            icon: disciplineIcon(discipline),
                            isSelected: department == discipline
                        ) {
                            SBHaptics.selection()
                            department = discipline
                        }
                    }
                }
            }

            // Class year — tailors AI depth
            SBFieldSection(title: "Sınıf", icon: "calendar") {
                FlowLayout(spacing: SBSpacing.sm) {
                    ForEach(classYears, id: \.self) { year in
                        SBSelectPill(label: year, isSelected: classYear == year) {
                            SBHaptics.selection()
                            classYear = year
                        }
                    }
                }
            }

            // Goal — tailors AI focus (discipline-specific)
            SBFieldSection(title: "Hedef", icon: "target") {
                FlowLayout(spacing: SBSpacing.sm) {
                    ForEach(goals(for: department), id: \.self) { option in
                        SBSelectPill(label: option, isSelected: goal == option) {
                            SBHaptics.selection()
                            goal = option
                        }
                    }
                }
            }
        }
    }

    private var facultyField: some View {
        HStack(spacing: SBSpacing.md) {
            Image(systemName: "building.columns")
                .sbScaledFont(size: 18, weight: .medium)
                .foregroundStyle(isFacultyFocused ? SBColors.blue : SBColors.muted)
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
        .frame(height: 56)
        .background(isFacultyFocused ? SBColors.fieldFocus : SBColors.field)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFacultyFocused ? SBColors.blue.opacity(0.7) : SBColors.line, lineWidth: isFacultyFocused ? 1.4 : 1)
        )
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
            if let savedYear = metadata["sourcebase_class_year"]?.stringValue,
               classYears.contains(savedYear) {
                classYear = savedYear
            }
            if let savedGoal = metadata["sourcebase_goal"]?.stringValue,
               goals(for: department).contains(savedGoal) {
                goal = savedGoal
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
            await session.updateProfile(faculty: faculty, department: department, classYear: classYear, goal: goal)
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
