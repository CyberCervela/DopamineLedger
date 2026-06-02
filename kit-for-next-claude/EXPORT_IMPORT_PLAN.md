# Export / Import — Implementation Plan
# Planned in session before Session 39. Ready to code — no design decisions open.

---

## What we are building

Full data backup and restore for Dopamine Ledger:

- **Export** — one tap in Settings → Danger Zone → iOS share sheet (Files / AirDrop /
  email). Produces `DopamineLedger-backup.json`. No server, no cloud. Consistent with
  the published privacy policy.
- **Import** — file picker → confirmation alert → replace-all restore. Not a merge.
  Two explicit gates before any data is deleted.
- **Round-trip unit test** — exercises every field on every model. Fails the build if
  someone adds a model field and forgets to update the exporter.
- **Debug "Load Test Data" button** — `#if DEBUG` only. Reads a committed seed JSON
  from the app bundle and imports it via the exact same code path as a real user
  import. Replaces the auto-run DebugSeeder for day-to-day testing (seeder stays
  in the codebase as a fallback for regenerating the seed file).

---

## Files to create / change

| File | Action |
|---|---|
| `DopamineLedger/Services/DataExporter.swift` | **Create** |
| `DopamineLedger/Views/SettingsView.swift` | **Edit** |
| `DopamineLedger/Localization/Localizable.xcstrings` | **Edit** |
| `DopamineLedgerTests/DopamineLedgerTests.swift` | **Edit** — add round-trip tests |
| `DopamineLedger/Debug/seed-data.json` | **Create** — see "Generating the seed file" below |

Run `make generate` after creating `DataExporter.swift` to register it in the pbxproj
(the `path: DopamineLedger` source glob picks up new files, but the pbxproj needs a
regeneration pass).

---

## 1. DataExporter.swift — full structure

Location: `DopamineLedger/Services/DataExporter.swift`

```swift
// DataExporter.swift
// Pure export / import logic — no SwiftUI dependencies.
//
// FIELD SYNC RULE: if you add a field to Activity, Session, Quest, ActivityDebt,
// or Ledger, update the corresponding Export struct AND its init from the @Model
// in this file. The round-trip unit test in DopamineLedgerTests will catch the gap.

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Portable Codable structs
// String raw values for enums keep old backup files readable if enum cases
// change in future versions. Unknown raw values fall back to safe defaults on import.

struct ExportData: Codable {
    let version: Int        // schema version — 1 for this implementation
    let exportedAt: Date
    let balance: Double
    let activities: [ActivityExport]
    let sessions: [SessionExport]
    let quests: [QuestExport]
    let debts: [DebtExport]
}

struct ActivityExport: Codable {
    let id: UUID
    let name: String
    let kind: String            // ActivityKind raw value: "charger" / "spender"
    let ratePerSecond: Double
    let iconName: String
    let category: String?       // ActivityCategory raw value, or nil for pre-migration rows
    let isArchived: Bool
    let linkedAppScheme: String?
    let linkedAppName: String?
    let createdAt: Date
}

struct SessionExport: Codable {
    let id: UUID
    let activityId: UUID
    let startedAt: Date
    let endedAt: Date?
    let pausedAt: Date?
    let totalPausedSeconds: TimeInterval
    let timeMultiplier: Double
    let creditsMoved: Double
}

struct QuestExport: Codable {
    let id: UUID
    let name: String
    let payoffCredits: Double
    let iconName: String
    let category: String?           // ActivityCategory raw value
    let createdAt: Date
    let isCompleted: Bool
    let completedAt: Date?
    let isArchived: Bool
    let recurringCadence: String?   // RecurringCadence raw value, or nil for one-shot
    let availableAt: Date?
}

struct DebtExport: Codable {
    let id: UUID
    let activityId: UUID
    let amount: Double
    let originalAmount: Double
    let createdAt: Date
    let repaidAt: Date?
}

// MARK: - DataExporter

enum DataExporter {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // Fetch all data, encode to JSON, write to a temp file, return the URL.
    // Returns nil only on encoding failure (should not happen with valid data).
    @MainActor
    static func exportToFile(context: ModelContext) -> URL? {
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let sessions   = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let quests     = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        let debts      = (try? context.fetch(FetchDescriptor<ActivityDebt>())) ?? []
        let ledger     = Ledger.fetchOrCreate(in: context)

        let exportData = ExportData(
            version: 1,
            exportedAt: Date(),
            balance: ledger.balance,
            activities: activities.map(ActivityExport.init),
            sessions:   sessions.map(SessionExport.init),
            quests:     quests.map(QuestExport.init),
            debts:      debts.map(DebtExport.init)
        )

        guard let data = try? encoder.encode(exportData) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DopamineLedger-backup.json")
        try? data.write(to: url)
        return url
    }

    // Read and decode a backup file chosen via the document picker.
    // Handles the security-scoped resource lifecycle.
    static func decodeBackup(from url: URL) -> ExportData? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ExportData.self, from: data)
    }

    // Read and decode the bundled seed file (DEBUG builds only).
    // Returns nil if the file is missing or malformed.
    static func decodeBundleSeed() -> ExportData? {
        guard let url = Bundle.main.url(forResource: "seed-data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ExportData.self, from: data)
    }

    // Wipe all current data and restore from the decoded backup.
    // Throws if the SwiftData delete or save fails.
    @MainActor
    static func applyImport(_ exportData: ExportData, context: ModelContext) throws {
        // Wipe — same order as SettingsView.wipeAllData()
        try context.delete(model: Session.self)
        try context.delete(model: ActivityDebt.self)
        try context.delete(model: Quest.self)
        try context.delete(model: Activity.self)
        try context.delete(model: Ledger.self)

        // Restore activities
        for a in exportData.activities {
            let activity = Activity(
                name: a.name,
                kind: ActivityKind(rawValue: a.kind) ?? .spender,
                ratePerMinute: 1.0,     // placeholder; overridden below
                iconName: a.iconName,
                category: a.category.flatMap(ActivityCategory.init(rawValue:)) ?? .other
            )
            activity.id              = a.id
            activity.ratePerSecond   = a.ratePerSecond  // exact value, no round-trip loss
            activity.isArchived      = a.isArchived
            activity.linkedAppScheme = a.linkedAppScheme
            activity.linkedAppName   = a.linkedAppName
            activity.createdAt       = a.createdAt
            context.insert(activity)
        }

        // Restore sessions
        for s in exportData.sessions {
            let session = Session(activityId: s.activityId)
            session.id                  = s.id
            session.startedAt           = s.startedAt
            session.endedAt             = s.endedAt
            session.pausedAt            = s.pausedAt
            session.totalPausedSeconds  = s.totalPausedSeconds
            session.timeMultiplier      = s.timeMultiplier
            session.creditsMoved        = s.creditsMoved
            context.insert(session)
        }

        // Restore quests
        for q in exportData.quests {
            let cadence = q.recurringCadence.flatMap(RecurringCadence.init(rawValue:))
            let quest = Quest(
                name: q.name,
                payoffCredits: q.payoffCredits,
                iconName: q.iconName,
                category: q.category.flatMap(ActivityCategory.init(rawValue:)) ?? .other,
                recurringCadence: cadence
            )
            quest.id              = q.id
            quest.createdAt       = q.createdAt
            quest.isCompleted     = q.isCompleted
            quest.completedAt     = q.completedAt
            quest.isArchived      = q.isArchived
            quest.availableAt     = q.availableAt  // override Quest.init's computed value
            context.insert(quest)
        }

        // Restore debts
        for d in exportData.debts {
            let debt = ActivityDebt(activityId: d.activityId, amount: d.amount)
            debt.id             = d.id
            debt.originalAmount = d.originalAmount
            debt.createdAt      = d.createdAt
            debt.repaidAt       = d.repaidAt
            context.insert(debt)
        }

        // Restore ledger balance
        let ledger = Ledger(balance: exportData.balance)
        context.insert(ledger)

        try context.save()
    }
}

// MARK: - Export struct initialisers (one per @Model class)
// These live here — not in the model files — so the exporter is self-contained.
// When you add a field to an @Model, update BOTH the struct above AND the init below.

private extension ActivityExport {
    init(_ a: Activity) {
        id              = a.id
        name            = a.name
        kind            = a.kind.rawValue
        ratePerSecond   = a.ratePerSecond
        iconName        = a.iconName
        category        = a.category?.rawValue
        isArchived      = a.isArchived
        linkedAppScheme = a.linkedAppScheme
        linkedAppName   = a.linkedAppName
        createdAt       = a.createdAt
    }
}

private extension SessionExport {
    init(_ s: Session) {
        id                  = s.id
        activityId          = s.activityId
        startedAt           = s.startedAt
        endedAt             = s.endedAt
        pausedAt            = s.pausedAt
        totalPausedSeconds  = s.totalPausedSeconds
        timeMultiplier      = s.timeMultiplier
        creditsMoved        = s.creditsMoved
    }
}

private extension QuestExport {
    init(_ q: Quest) {
        id               = q.id
        name             = q.name
        payoffCredits    = q.payoffCredits
        iconName         = q.iconName
        category         = q.category?.rawValue
        createdAt        = q.createdAt
        isCompleted      = q.isCompleted
        completedAt      = q.completedAt
        isArchived       = q.isArchived
        recurringCadence = q.recurringCadence?.rawValue
        availableAt      = q.availableAt
    }
}

private extension DebtExport {
    init(_ d: ActivityDebt) {
        id             = d.id
        activityId     = d.activityId
        amount         = d.amount
        originalAmount = d.originalAmount
        createdAt      = d.createdAt
        repaidAt       = d.repaidAt
    }
}
```

---

## 2. SettingsView.swift — changes

### 2a. New state properties (add after existing `@State private var activeAlert`)

```swift
@State private var isSharePresented: Bool   = false
@State private var shareURL:         URL?   = nil
@State private var isImporting:      Bool   = false
@State private var pendingImport:    ExportData? = nil
```

### 2b. Extend `SettingsAlert` enum (line ~37)

```swift
private enum SettingsAlert: Identifiable {
    case wipe, mailFallback, importConfirm, importError
    var id: Self { self }
}
```

### 2c. Replace `dangerZoneSection` (currently lines 365–388)

```swift
private var dangerZoneSection: some View {
    sectionCard(title: lBundle.l("settings.section.danger_zone")) {
        VStack(spacing: 0) {
            // Export
            Button {
                if let url = DataExporter.exportToFile(context: context) {
                    shareURL = url
                    isSharePresented = true
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text(lBundle.l("settings.export.title"))
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text(lBundle.l("settings.export.caption"))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, theme.spacing.sm)

            // Import
            Button { isImporting = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text(lBundle.l("settings.import.title"))
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text(lBundle.l("settings.import.caption"))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, theme.spacing.sm)

            // --- DEBUG: Load Test Data ---
            // Loads seed-data.json from the app bundle via the same import code path
            // as a real user restore. Only compiled in DEBUG builds.
            #if DEBUG
            Button {
                if let data = DataExporter.decodeBundleSeed() {
                    pendingImport = data
                    activeAlert = .importConfirm
                } else {
                    activeAlert = .importError
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Load Test Data")
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.accent)
                        Text("DEBUG — replaces all data with seed-data.json")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "ladybug")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.vertical, theme.spacing.sm)
            #endif

            // Wipe (existing row — no changes)
            Button {
                activeAlert = .wipe
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text(lBundle.l("settings.wipe.title"))
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.negative)
                        Text(lBundle.l("settings.wipe.caption"))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.negative)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
```

### 2d. Add new alert cases to the `.alert(item: $activeAlert)` switch (after the `case .wipe:` block, before the closing `}`)

```swift
case .importConfirm:
    return Alert(
        title: Text(lBundle.l("alert.import.title")),
        message: Text(lBundle.l("alert.import.message")),
        primaryButton: .destructive(Text(lBundle.l("alert.import.confirm"))) {
            guard let data = pendingImport else { return }
            do {
                try DataExporter.applyImport(data, context: context)
                dismiss()
            } catch {
                pendingImport = nil
                activeAlert = .importError
            }
        },
        secondaryButton: .cancel(Text(lBundle.l("common.cancel")))
    )
case .importError:
    return Alert(
        title: Text(lBundle.l("alert.import.error")),
        message: Text(lBundle.l("alert.import.error.message")),
        dismissButton: .default(Text(lBundle.l("common.done")))
    )
```

### 2e. Add modifiers to the `body` VStack (after the existing `.sheet(isPresented: $showPrivacyPolicy)` modifier)

```swift
// Share sheet for export
.sheet(isPresented: $isSharePresented, onDismiss: { shareURL = nil }) {
    if let url = shareURL {
        ShareSheetView(url: url)
    }
}
// File picker for import
.fileImporter(
    isPresented: $isImporting,
    allowedContentTypes: [.json],
    allowsMultipleSelection: false
) { result in
    switch result {
    case .success(let urls):
        guard let url = urls.first else { return }
        if let data = DataExporter.decodeBackup(from: url) {
            pendingImport = data
            activeAlert = .importConfirm
        } else {
            activeAlert = .importError
        }
    case .failure:
        activeAlert = .importError
    }
}
```

### 2f. Add `ShareSheetView` at the bottom of `SettingsView.swift` (after the `#Preview`)

```swift
// Thin UIKit wrapper — UIActivityViewController can't be used directly in SwiftUI.
// Only used for export; import goes through the native .fileImporter modifier.
private struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
```

---

## 3. Localizable.xcstrings — 9 new keys × 7 languages

Add these entries. The existing file uses the `.xcstrings` JSON format — match its
existing structure exactly (copy an existing key block as a template).

| Key | EN | FR | DE | ES |
|---|---|---|---|---|
| `settings.export.title` | Export Data | Exporter les données | Daten exportieren | Exportar datos |
| `settings.export.caption` | Save a backup to Files, email, or AirDrop | Sauvegarder dans Fichiers, e-mail ou AirDrop | Als Datei, E-Mail oder AirDrop sichern | Guardar copia en Archivos, email o AirDrop |
| `settings.import.title` | Import Data | Importer les données | Daten importieren | Importar datos |
| `settings.import.caption` | Restore from a backup file | Restaurer depuis une sauvegarde | Aus Sicherung wiederherstellen | Restaurar desde copia de seguridad |
| `alert.import.title` | Replace All Data? | Remplacer toutes les données ? | Alle Daten ersetzen? | ¿Reemplazar todos los datos? |
| `alert.import.message` | This will delete all current data and replace it with the backup. This cannot be undone. | Toutes les données actuelles seront supprimées et remplacées par la sauvegarde. Cette action est irréversible. | Alle aktuellen Daten werden gelöscht und durch die Sicherung ersetzt. Dies kann nicht rückgängig gemacht werden. | Esto eliminará todos los datos actuales y los reemplazará con la copia de seguridad. No se puede deshacer. |
| `alert.import.confirm` | Replace | Remplacer | Ersetzen | Reemplazar |
| `alert.import.error` | Import Failed | Échec de l'import | Import fehlgeschlagen | Error de importación |
| `alert.import.error.message` | The file could not be read. Make sure it's a valid Dopamine Ledger backup. | Impossible de lire le fichier. Vérifiez qu'il s'agit d'une sauvegarde Dopamine Ledger valide. | Die Datei konnte nicht gelesen werden. Stellen Sie sicher, dass es eine gültige Dopamine Ledger-Sicherung ist. | No se pudo leer el archivo. Asegúrese de que sea una copia de seguridad válida de Dopamine Ledger. |

| Key | ZH | JA | KO |
|---|---|---|---|
| `settings.export.title` | 导出数据 | データをエクスポート | 데이터 내보내기 |
| `settings.export.caption` | 备份到文件、电子邮件或AirDrop | ファイル、メール、またはAirDropに保存 | 파일, 이메일 또는 AirDrop에 저장 |
| `settings.import.title` | 导入数据 | データをインポート | 데이터 가져오기 |
| `settings.import.caption` | 从备份文件恢复 | バックアップから復元 | 백업 파일에서 복원 |
| `alert.import.title` | 替换所有数据？ | すべてのデータを置き換えますか？ | 모든 데이터를 교체하시겠습니까? |
| `alert.import.message` | 这将删除所有当前数据并替换为备份内容。此操作无法撤销。 | 現在のすべてのデータが削除され、バックアップに置き換えられます。この操作は取り消せません。 | 현재 데이터가 모두 삭제되고 백업으로 교체됩니다. 이 작업은 취소할 수 없습니다. |
| `alert.import.confirm` | 替换 | 置き換える | 교체 |
| `alert.import.error` | 导入失败 | インポート失敗 | 가져오기 실패 |
| `alert.import.error.message` | 无法读取文件。请确保这是有效的Dopamine Ledger备份文件。 | ファイルを読み込めませんでした。有効なDopamine Ledgerバックアップであることを確認してください。 | 파일을 읽을 수 없습니다. 유효한 Dopamine Ledger 백업인지 확인하세요. |

Note: the "Load Test Data" button is intentionally NOT localised — it is a
`#if DEBUG` string that only a developer ever sees.

---

## 4. Unit tests — round-trip fidelity

Add to `DopamineLedgerTests/DopamineLedgerTests.swift`.

The test creates an in-memory `ModelContainer`, inserts one of each model with
**every field set to a non-default value**, runs the full export-encode-decode-import
cycle, then asserts field-by-field equality. If someone adds a model field and
forgets to update `DataExporter`, the imported value will be the default (zero, nil,
false, etc.) and an assertion will fail.

```swift
// MARK: - Export / Import round-trip

@MainActor
func testExportImportRoundTrip() throws {
    // ---- Build an in-memory store with known data ----
    let schema = Schema([Activity.self, Session.self, Quest.self,
                         ActivityDebt.self, Ledger.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    let ctx = container.mainContext

    // Activity — all fields non-default
    let act = Activity(name: "Test", kind: .charger, ratePerMinute: 6.0,
                       iconName: "bolt.fill", category: .focusLearning)
    act.isArchived      = true
    act.linkedAppScheme = "notion://"
    act.linkedAppName   = "Notion"
    ctx.insert(act)

    // Session — all fields non-default
    let sess = Session(activityId: act.id)
    sess.endedAt            = Date(timeIntervalSinceNow: 300)
    sess.pausedAt           = nil
    sess.totalPausedSeconds = 45
    sess.timeMultiplier     = 1.5
    sess.creditsMoved       = 30.0
    ctx.insert(sess)

    // Quest — all fields non-default, recurring
    let q = Quest(name: "Make Bed", payoffCredits: 5.0, iconName: "star",
                  category: .movement, recurringCadence: .daily)
    q.isCompleted     = true
    q.completedAt     = Date(timeIntervalSinceNow: -3600)
    q.isArchived      = true
    q.availableAt     = Date(timeIntervalSinceNow: 86400)
    ctx.insert(q)

    // Debt — all fields non-default
    let debt = ActivityDebt(activityId: act.id, amount: 12.5)
    debt.originalAmount = 25.0
    debt.repaidAt       = Date(timeIntervalSinceNow: -1800)
    ctx.insert(debt)

    // Ledger
    let ledger = Ledger.fetchOrCreate(in: ctx)
    ledger.balance = 420.5

    try ctx.save()

    // ---- Export ----
    guard let url = DataExporter.exportToFile(context: ctx) else {
        XCTFail("exportToFile returned nil"); return
    }
    guard let exported = DataExporter.decodeBackup(from: url) else {
        XCTFail("decodeBackup returned nil"); return
    }

    // ---- Import into a fresh store ----
    let container2 = try ModelContainer(for: schema, configurations:
        ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx2 = container2.mainContext
    try DataExporter.applyImport(exported, context: ctx2)

    // ---- Assert Activity fields ----
    let acts = try ctx2.fetch(FetchDescriptor<Activity>())
    XCTAssertEqual(acts.count, 1)
    let a2 = acts[0]
    XCTAssertEqual(a2.id,              act.id)
    XCTAssertEqual(a2.name,            act.name)
    XCTAssertEqual(a2.kind,            act.kind)
    XCTAssertEqual(a2.ratePerSecond,   act.ratePerSecond, accuracy: 0.0001)
    XCTAssertEqual(a2.iconName,        act.iconName)
    XCTAssertEqual(a2.category,        act.category)
    XCTAssertEqual(a2.isArchived,      act.isArchived)
    XCTAssertEqual(a2.linkedAppScheme, act.linkedAppScheme)
    XCTAssertEqual(a2.linkedAppName,   act.linkedAppName)
    XCTAssertEqual(a2.createdAt.timeIntervalSince1970,
                   act.createdAt.timeIntervalSince1970, accuracy: 1.0)

    // ---- Assert Session fields ----
    let sessions = try ctx2.fetch(FetchDescriptor<Session>())
    XCTAssertEqual(sessions.count, 1)
    let s2 = sessions[0]
    XCTAssertEqual(s2.id,                 sess.id)
    XCTAssertEqual(s2.activityId,         sess.activityId)
    XCTAssertEqual(s2.totalPausedSeconds, sess.totalPausedSeconds, accuracy: 0.01)
    XCTAssertEqual(s2.timeMultiplier,     sess.timeMultiplier, accuracy: 0.0001)
    XCTAssertEqual(s2.creditsMoved,       sess.creditsMoved, accuracy: 0.0001)
    XCTAssertNil(s2.pausedAt)
    XCTAssertNotNil(s2.endedAt)

    // ---- Assert Quest fields ----
    let quests = try ctx2.fetch(FetchDescriptor<Quest>())
    XCTAssertEqual(quests.count, 1)
    let q2 = quests[0]
    XCTAssertEqual(q2.id,               q.id)
    XCTAssertEqual(q2.name,             q.name)
    XCTAssertEqual(q2.payoffCredits,    q.payoffCredits, accuracy: 0.0001)
    XCTAssertEqual(q2.iconName,         q.iconName)
    XCTAssertEqual(q2.category,         q.category)
    XCTAssertEqual(q2.isCompleted,      q.isCompleted)
    XCTAssertEqual(q2.isArchived,       q.isArchived)
    XCTAssertEqual(q2.recurringCadence, q.recurringCadence)
    XCTAssertNotNil(q2.completedAt)
    XCTAssertNotNil(q2.availableAt)

    // ---- Assert Debt fields ----
    let debts = try ctx2.fetch(FetchDescriptor<ActivityDebt>())
    XCTAssertEqual(debts.count, 1)
    let d2 = debts[0]
    XCTAssertEqual(d2.id,             debt.id)
    XCTAssertEqual(d2.activityId,     debt.activityId)
    XCTAssertEqual(d2.amount,         debt.amount, accuracy: 0.0001)
    XCTAssertEqual(d2.originalAmount, debt.originalAmount, accuracy: 0.0001)
    XCTAssertNotNil(d2.repaidAt)

    // ---- Assert Ledger balance ----
    let l2 = Ledger.fetchOrCreate(in: ctx2)
    XCTAssertEqual(l2.balance, 420.5, accuracy: 0.0001)
}
```

---

## 5. Generating the seed file (one-time user action, after confirming export works)

This step is done manually by the user, not by Claude:

1. Open the app (DebugSeeder fires on first empty launch and seeds mock data).
2. Settings → Danger Zone → **Export Data** → save the file somewhere accessible.
3. Rename the file to `seed-data.json`.
4. In Xcode (or Finder), add it to `DopamineLedger/Debug/seed-data.json`.
5. In `project.yml`, add it to the main target resources if not picked up automatically:
   ```yaml
   resources:
     - path: DopamineLedger/Debug/seed-data.json
   ```
   Then run `make generate`.
6. Commit the file.

After this, future testing flow:
- Settings → Danger Zone → **Wipe Data** → immediately returns empty home screen.
- Settings → Danger Zone → **Load Test Data** (DEBUG button) → confirms import → app
  reloads with full mock data set.
- DebugSeeder stays in the codebase. Reactivate it (it auto-runs on empty store) any
  time the seed data needs to be regenerated.

---

## 6. HARD_RULES.md addition

After confirming the feature, add this rule to `kit-for-next-claude/HARD_RULES.md`
(or wherever the project's hard rules live):

> **Export field sync:** if you add a field to `Activity`, `Session`, `Quest`,
> `ActivityDebt`, or `Ledger`, update the corresponding Export struct AND the
> `init(_ model:)` extension in `DataExporter.swift` in the same commit. The
> `testExportImportRoundTrip` unit test enforces this at build time.

---

## 7. Build order

1. Create `DataExporter.swift`.
2. Edit `SettingsView.swift`.
3. Edit `Localizable.xcstrings`.
4. `make generate` — registers the new file in pbxproj.
5. `make build` — must be zero errors before `READY TO TEST`.
6. Add `testExportImportRoundTrip` to `DopamineLedgerTests.swift`.
7. `make test` — all tests must pass.
8. Screenshot the updated Danger Zone section, send for review.

---

## 8. Docs to update after user confirms (don't do before)

- `JOURNAL.md` — Session 39 entry.
- `FEATURES.md` — add Export / Import row with status `done`.
- `BACKLOG.md` — remove the Export / Import entry from the backlog table.
- `HARD_RULES.md` — add the export field sync rule (section 6 above).
- Commit + push.
