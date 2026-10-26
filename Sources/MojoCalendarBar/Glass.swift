import SwiftUI
import AppKit

/// ทำหน้าต่าง MenuBarExtra ให้เป็น Liquid Glass แบบเมนูของระบบ (Sound / Wi-Fi)
/// MenuBarExtra(.window) ใส่ NSVisualEffectView แบบเก่ามาให้เอง (ทึบ มุมเล็ก ขอบเทา)
/// ⇒ ซ่อนพื้นเดิม + ทำหน้าต่างโปร่ง แล้ววาด glassEffect เองใน SwiftUI
extension View {
    @ViewBuilder func glassBackground() -> some View {
        if #available(macOS 26, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Glass.radius, style: .continuous))
                .background(TransparentWindow())
        } else {
            self // macOS เก่า: ใช้พื้นเดิมของระบบ
        }
    }
}

enum Glass {
    static let radius: CGFloat = 22
}

/// เข้าถึง NSWindow ที่ห่อ view นี้ แล้วล้างพื้นของระบบออก
private struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Probe: NSView {
        private var resizeObserver: NSObjectProtocol?
        /// พื้นเก่าที่ซ่อนไว้ตอนเปิดหน้าต่างครั้งแรก — ตอน resize ซ่อนซ้ำเฉพาะตัวเหล่านี้
        /// ⚠️ ห้ามไล่หา effect view ใหม่หลัง SwiftUI วาดแล้ว: Divider / วงวันนี้ อยู่บน effect view
        /// ขนาดเต็มหน้าต่างของ SwiftUI เอง (เคยหายทั้งคู่ 21ต.ค.69)
        private var oldBackgrounds: [WeakFX] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            if oldBackgrounds.isEmpty, let root = window.contentView?.superview ?? window.contentView {
                oldBackgrounds = Self.collectEffectViews(in: root).map(WeakFX.init)
            }
            apply(to: window)
            if resizeObserver == nil {
                resizeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification, object: window, queue: .main
                ) { [weak self] _ in
                    guard let self, let w = self.window else { return }
                    self.apply(to: w)
                }
            }
        }

        deinit { if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) } }

        private func apply(to window: NSWindow) {
            window.isOpaque = false
            window.backgroundColor = .clear
            // เงาของหน้าต่างคำนวณจากกรอบสี่เหลี่ยม ⇒ โผล่เป็นแถบเทาเหลี่ยมใต้กระจก (เจอใน mojo-disk-bar 21ต.ค.69)
            // invalidateShadow ซ้ำก็ไม่หาย ⇒ ปิดเงาหน้าต่าง ใช้ขอบของ glassEffect แทน
            window.hasShadow = false
            for fx in oldBackgrounds.compactMap(\.view) {
                fx.state = .inactive
                fx.alphaValue = 0
            }
            if let root = window.contentView?.superview ?? window.contentView {
                // ตัดมุมหน้าต่างให้โค้งเท่า glass ไม่งั้นมุมเหลี่ยมของกรอบเดิมโผล่
                root.wantsLayer = true
                root.layer?.backgroundColor = .clear
                root.layer?.cornerRadius = Glass.radius
                root.layer?.cornerCurve = .continuous
                root.layer?.masksToBounds = true
            }
        }

        private static func collectEffectViews(in view: NSView) -> [NSVisualEffectView] {
            view.subviews.flatMap { sub -> [NSVisualEffectView] in
                ((sub as? NSVisualEffectView).map { [$0] } ?? []) + collectEffectViews(in: sub)
            }
        }
    }

    final class WeakFX {
        weak var view: NSVisualEffectView?
        init(_ v: NSVisualEffectView) { view = v }
    }
}
