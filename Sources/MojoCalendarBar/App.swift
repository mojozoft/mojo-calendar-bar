import SwiftUI
import AppKit
import ServiceManagement

@main
struct MojoCalendarBarApp: App {
    @StateObject private var clock = DayClock()
    // ค่าเดียวกับใน CalendarView — ไอคอนต้องเปลี่ยนทันทีที่ผู้ใช้เลือก
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""
    @AppStorage("iconStyle") private var iconStyle = 0
    @AppStorage("iconColor") private var iconColor = ""
    @AppStorage("iconContent") private var iconContent = 0

    var body: some Scene {
        MenuBarExtra {
            CalendarView()
                .environmentObject(clock)
        } label: {
            let language = AppLanguage.resolve(langRaw)
            let text = DateText(language: language, era: Era.resolve(eraRaw, language: language), firstWeekday: 0)
            Image(nsImage: MenuIcon.make(
                text: text.menuBarText(clock.today, content: IconContent(rawValue: iconContent) ?? .day),
                style: IconStyle(rawValue: iconStyle) ?? .filled,
                color: IconColor(rawValue: iconColor) ?? .system))
            .accessibilityLabel(text.fullDate(clock.today))
        }
        .menuBarExtraStyle(.window)
    }
}

/// เก็บ "วันนี้" และอัปเดตเมื่อข้ามเที่ยงคืน / เครื่องตื่นจากหลับ / เปลี่ยนเวลา
final class DayClock: ObservableObject {
    @Published var today = Date()
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    init() {
        let refresh: (Notification) -> Void = { [weak self] _ in self?.tick() }
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main, using: refresh))
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main, using: refresh))
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: refresh))
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh))
        // กันพลาด: เช็คทุกนาที (ถูกมาก) เผื่อ notification ไม่มา
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let now = Date()
        if !Calendar.localGregorian.isDate(now, inSameDayAs: today) { today = now }
    }
}

/// เปิดเองตอนล็อกอิน (ใช้ได้เมื่อรันจาก .app เท่านั้น)
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("LaunchAtLogin error: \(error)")
        }
    }
}
