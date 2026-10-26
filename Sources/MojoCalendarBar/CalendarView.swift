import SwiftUI
import AppKit

struct CalendarView: View {
    @EnvironmentObject var clock: DayClock
    @AppStorage("era") private var eraRaw = Era.buddhist.rawValue
    @AppStorage("lang") private var langRaw = Lang.th.rawValue
    @AppStorage("titleFormat") private var titleFormat = 0
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @State private var month = Date()
    @State private var selected: Date?
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var era: Era { Era(rawValue: eraRaw) ?? .buddhist }
    private var lang: Lang { Lang(rawValue: langRaw) ?? .th }
    private let cal = ThaiDate.calendar

    var body: some View {
        VStack(spacing: 10) {
            header
            Picker("", selection: $eraRaw) {
                ForEach(Era.allCases) { Text($0.label(lang)).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)

            grid
            Divider()
            info
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 296) // ความกว้างคงที่ — หน้าต่างเปลี่ยนขนาดแล้วกรอบเดิมของระบบโผล่
        .glassBackground()
        .onAppear { month = clock.today; selected = nil }
    }

    // MARK: หัว: เดือน ปี + ปุ่มเลื่อน
    private var header: some View {
        HStack {
            Text(ThaiDate.monthTitle(month, era: era, lang: lang, format: titleFormat))
                .font(.system(size: 15, weight: .semibold))
                .contentShape(Rectangle())
                .onTapGesture { titleFormat = (titleFormat + 1) % ThaiDate.monthTitleFormatCount }
                .help(lang.formatHelp)
            Spacer()
            // focusable(false): กันกรอบโฟกัสสีฟ้าค้างที่ปุ่มแรกตอนเปิดหน้าต่าง
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }.focusable(false)
            Button(lang.today) { month = clock.today; selected = nil }.focusable(false)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }.focusable(false)
        }
        .buttonStyle(.borderless)
    }

    // MARK: กริดวัน
    private var grid: some View {
        let days = ThaiDate.gridDays(for: month)
        let thisMonth = cal.component(.month, from: month)
        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                if showWeekNumbers { Text("").frame(width: 22) }
                ForEach(0..<7, id: \.self) { i in
                    Text(lang.weekdayShort[i])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(i == 0 ? Color.red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<6, id: \.self) { w in
                HStack(spacing: 0) {
                    if showWeekNumbers {
                        Text("\(ThaiDate.weekOfYear(days[w * 7 + 1]))")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                            .frame(width: 22)
                    }
                    ForEach(0..<7, id: \.self) { d in
                        dayCell(days[w * 7 + d], inMonth: cal.component(.month, from: days[w * 7 + d]) == thisMonth, col: d)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date, inMonth: Bool, col: Int) -> some View {
        let isToday = cal.isDate(date, inSameDayAs: clock.today)
        let isSelected = selected.map { cal.isDate(date, inSameDayAs: $0) } ?? false
        return Text("\(cal.component(.day, from: date))")
            .font(.system(size: 12, weight: isToday ? .bold : .regular).monospacedDigit())
            .foregroundStyle(isToday ? Color.white : (col == 0 ? Color.red : Color.primary))
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
    private var info: some View {
        let d = selected ?? clock.today
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: clock.today), to: cal.startOfDay(for: d)).day ?? 0
        return VStack(alignment: .leading, spacing: 3) {
            Text(ThaiDate.fullDate(d, era: era, lang: lang)).font(.system(size: 13, weight: .medium))
            if diff != 0 {
                // verbatim — Text("\(Int)") จะใส่ลูกน้ำคั่นหลักพัน
                Text(verbatim: lang.daysAway(diff))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ท้าย: ตั้งค่า + สลับภาษา + ออก
    private var footer: some View {
        HStack {
            Menu {
                Toggle(lang.showWeekNumbers, isOn: $showWeekNumbers)
                Toggle(lang.launchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }
                Divider()
                Button(lang.copyFull(era)) { copy(ThaiDate.fullDate(selected ?? clock.today, era: era, lang: lang)) }
                Button(lang.copyShort) { copy(ThaiDate.shortDate(selected ?? clock.today, era: era, lang: lang)) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .focusable(false)
            .fixedSize()
            Spacer()
            // ปุ่มสลับภาษา (ป้ายบอกภาษาปัจจุบัน)
            Button { langRaw = lang.toggled.rawValue } label: {
                Text(lang.badge)
                    .font(.system(size: 11, weight: .semibold).monospaced())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(lang.switchHelp)
            Spacer()
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help(lang.quit)
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
