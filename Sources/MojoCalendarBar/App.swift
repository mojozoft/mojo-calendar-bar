import SwiftUI
import AppKit
import ServiceManagement

@main
struct MojoCalendarBarApp: App {
    @StateObject private var clock = DayClock()

    var body: some Scene {
        MenuBarExtra {
            CalendarView()
                .environmentObject(clock)
        } label: {
            Image(nsImage: MenuIcon.make(day: ThaiDate.calendar.component(.day, from: clock.today)))
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
        if !ThaiDate.calendar.isDate(now, inSameDayAs: today) { today = now }
    }
}

/// ไอคอนบนแถบเมนู: กรอบปฏิทินเล็ก ๆ + เลขวันที่ (template image ⇒ เปลี่ยนสีตามธีมเอง)
enum MenuIcon {
    static func make(day: Int) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let img = NSImage(size: size, flipped: false) { rect in
            // กรอบทึบมุมมน แล้วเจาะตัวเลขออก (ตัวเลข = โปร่ง เห็นสีแถบเมนู)
            let box = NSRect(x: 1, y: 0.5, width: 20, height: 15)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()

            let text = "\(day)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let ts = text.size(withAttributes: attrs)
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            text.draw(at: NSPoint(x: box.midX - ts.width / 2, y: box.midY - ts.height / 2),
                      withAttributes: attrs)
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            return true
        }
        img.isTemplate = true
        return img
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
