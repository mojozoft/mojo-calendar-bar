import SwiftUI
import AppKit

struct CalendarView: View {
    @EnvironmentObject var clock: DayClock
    // ค่าที่จำไว้ · "" / "system" / 0 = ยังไม่เคยเลือก ⇒ ตามภาษา/ถิ่นของเครื่อง
    @AppStorage("era") private var eraRaw = ""
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("firstWeekday") private var firstWeekday = 0
    @AppStorage("titleFormat") private var titleFormat = 0
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @State private var month = Date()
    @State private var selected: Date?
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var language: String { AppLanguage.resolve(langRaw) }
    private var era: Era { Era.resolve(eraRaw, language: language) }
    private var text: DateText { DateText(language: language, era: era, firstWeekday: firstWeekday) }
    private var t: Strings { text.strings }
    private var cal: Calendar { text.calendar }

    /// ตัวเลือกบนปุ่มสลับ: ค.ศ. + ระบบปีที่เลือกอยู่/ประจำถิ่น · ไม่มีระบบอื่น ⇒ ซ่อนปุ่ม (เลือกได้ในเมนู ⋯)
    private var eraChoices: [Era] {
        let alt = era != .gregorian ? era : Era.regional(region: Locale.current.region?.identifier, language: language)
        guard let alt else { return [] }
        // ไทย: พ.ศ. ก่อน (แบบเดิม) · ที่อื่น: ค.ศ. ก่อน
        return alt == .buddhist ? [.buddhist, .gregorian] : [.gregorian, alt]
    }

    var body: some View {
        let text = self.text
        VStack(spacing: 10) {
            header(text)
            if !eraChoices.isEmpty {
                Picker("", selection: Binding(get: { era.rawValue }, set: { eraRaw = $0 })) {
                    ForEach(eraChoices) { Text(text.eraLabel($0)).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .focusable(false)
            }

            grid(text)
            Divider()
            info(text)
            Divider()
            footer(text)
        }
        .padding(16)
        .frame(width: 296) // ความกว้างคงที่ — หน้าต่างเปลี่ยนขนาดแล้วกรอบเดิมของระบบโผล่
        .glassBackground()
        .onAppear { month = clock.today; selected = nil }
    }

    // MARK: หัว: เดือน ปี + ปุ่มเลื่อน
    private func header(_ text: DateText) -> some View {
        HStack {
            Text(text.monthTitle(month, format: titleFormat))
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentShape(Rectangle())
                .onTapGesture { titleFormat = (titleFormat + 1) % DateText.monthTitleFormatCount }
                .help(t("Click to change format"))
            Spacer()
            // focusable(false): กันกรอบโฟกัสสีฟ้าค้างที่ปุ่มแรกตอนเปิดหน้าต่าง
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }.focusable(false)
            Button(t("Today")) { month = clock.today; selected = nil }.focusable(false)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }.focusable(false)
        }
        .buttonStyle(.borderless)
    }

    // MARK: กริดวัน
    private func grid(_ text: DateText) -> some View {
        let days = text.gridDays(for: month)
        let thisMonth = cal.component(.month, from: month)
        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                if showWeekNumbers { Text("").frame(width: 22) }
                ForEach(text.weekdayHeaders(), id: \.weekday) { h in
                    Text(h.text)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(h.weekday == 1 ? Color.red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<6, id: \.self) { w in
                HStack(spacing: 0) {
                    if showWeekNumbers {
                        Text(verbatim: "\(text.weekOfYear(days[w * 7]))")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                            .frame(width: 22)
                    }
                    ForEach(0..<7, id: \.self) { d in
                        let day = days[w * 7 + d]
                        dayCell(day, inMonth: cal.component(.month, from: day) == thisMonth)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date, inMonth: Bool) -> some View {
        let isToday = cal.isDate(date, inSameDayAs: clock.today)
        let isSelected = selected.map { cal.isDate(date, inSameDayAs: $0) } ?? false
        let isSunday = cal.component(.weekday, from: date) == 1
        return Text(verbatim: "\(cal.component(.day, from: date))")
            .font(.system(size: 12, weight: isToday ? .bold : .regular).monospacedDigit())
            .foregroundStyle(isToday ? Color.white : (isSunday ? Color.red : Color.primary))
            .opacity(inMonth ? 1 : 0.3)
            .frame(width: 28, height: 26)
            .background(
                Circle().fill(isToday ? Color.accentColor : (isSelected ? Color.secondary.opacity(0.25) : .clear))
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                selected = date
                if !inMonth { month = date }
            }
    }

    // MARK: ข้อมูลวันที่เลือก (หรือวันนี้)
    private func info(_ text: DateText) -> some View {
        let d = selected ?? clock.today
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: clock.today), to: cal.startOfDay(for: d)).day ?? 0
        return VStack(alignment: .leading, spacing: 3) {
            Text(text.fullDate(d)).font(.system(size: 13, weight: .medium))
            if diff != 0 {
                Text(text.daysAway(diff))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ท้าย: ตั้งค่า + เลือกภาษา + ออก
    private func footer(_ text: DateText) -> some View {
        HStack {
            Menu {
                Toggle(t("Show week numbers"), isOn: $showWeekNumbers)
                Toggle(t("Open at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }
                Menu(t("Year system")) {
                    Picker("", selection: Binding(get: { era.rawValue }, set: { eraRaw = $0 })) {
                        ForEach(Era.allCases) { e in
                            Text(verbatim: "\(text.eraName(e)) (\(text.eraLabel(e)))").tag(e.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Menu(t("Start week on")) {
                    Picker("", selection: $firstWeekday) {
                        Text(t("Region default")).tag(0)
                        Divider()
                        ForEach([1, 2, 7], id: \.self) { Text(text.weekdayName($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Divider()
                Button(t.format("Copy date (%@)", text.eraLabel(era))) { copy(text.fullDate(selected ?? clock.today)) }
                Button(t("Copy short date")) { copy(text.shortDate(selected ?? clock.today)) }
                Divider()
                Button(t("Help")) { NSWorkspace.shared.open(text.siteURL("support/")) }
                Button(t("Mojozoft website")) { NSWorkspace.shared.open(text.siteURL("")) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .focusable(false)
            .fixedSize()
            Spacer()
            // เลือกภาษา (ป้ายบอกภาษาปัจจุบัน)
            Menu {
                Picker("", selection: $langRaw) {
                    Text(t("System language")).tag(AppLanguage.system)
                    Divider()
                    ForEach(AppLanguage.supported, id: \.self) { Text(AppLanguage.nativeName($0)).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(AppLanguage.badge(language))
                    .font(.system(size: 11, weight: .semibold).monospaced())
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .focusable(false)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.12)))
            .help(t("Language"))
            Spacer()
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help(t("Quit"))
                .focusable(false)
                .keyboardShortcut("q")
        }
    }

    private func shift(_ n: Int) {
        month = cal.date(byAdding: .month, value: n, to: month) ?? month
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
