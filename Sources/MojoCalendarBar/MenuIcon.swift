import AppKit

/// รูปแบบพื้นของไอคอนบนแถบเมนู (ค่าที่จำไว้: `iconStyle`)
enum IconStyle: Int, CaseIterable, Identifiable {
    case filled, outline, plain
    var id: Int { rawValue }
    var nameKey: String {
        switch self {
        case .filled: "Filled"
        case .outline: "Outline"
        case .plain: "No background"
        }
    }
}

/// สิ่งที่แสดงบนไอคอน (ค่าที่จำไว้: `iconContent`)
enum IconContent: Int, CaseIterable, Identifiable {
    // เลขดิบคือค่าที่จำไว้ (ห้ามเปลี่ยน) · ลำดับในเมนูตามลำดับประกาศ
    case day = 0, dayMonth = 1, dayMonthShortYear = 3, dayMonthYear = 2
    var id: Int { rawValue }
    var nameKey: String {
        switch self {
        case .day: "Day only"
        case .dayMonth: "Day and month"
        case .dayMonthShortYear: "Day, month and short year"
        case .dayMonthYear: "Day, month and full year"
        }
    }
}

/// สีไอคอน (ค่าที่จำไว้: `iconColor` · "" = ตามแถบเมนู = template image เปลี่ยนสีตามธีมเอง)
enum IconColor: String, CaseIterable, Identifiable {
    case system = "", accent, orange, red, pink, purple, blue, green, graphite
    var id: String { rawValue }

    /// nil = template · สีระบบเป็น dynamic color ⇒ วาดตอนแสดงผลจึงได้เฉดตามโหมดสว่าง/มืดเอง
    var nsColor: NSColor? {
        switch self {
        case .system: nil
        case .accent: .controlAccentColor
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        case .blue: .systemBlue
        case .green: .systemGreen
        case .graphite: .systemGray
        }
    }

    var nameKey: String {
        switch self {
        case .system: "Match menu bar"
        case .accent: "Accent color"
        case .orange: "Orange"
        case .red: "Red"
        case .pink: "Pink"
        case .purple: "Purple"
        case .blue: "Blue"
        case .green: "Green"
        case .graphite: "Graphite"
        }
    }

    /// วงกลมสีในเมนูเลือกสี
    var swatch: NSImage {
        let img = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { r in
            let path = NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5))
            if let c = self.nsColor {
                c.setFill(); path.fill()
            } else {
                // ตามแถบเมนู = ครึ่งดำครึ่งขาว
                NSColor.white.setFill(); path.fill()
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                NSColor.black.setFill()
                NSRect(x: 0, y: 0, width: r.width / 2, height: r.height).fill()
                NSGraphicsContext.restoreGraphicsState()
                NSColor.gray.setStroke(); path.lineWidth = 0.5; path.stroke()
            }
            return true
        }
        return img
    }
}

/// ไอคอนบนแถบเมนู: ข้อความวันที่ + พื้น 3 แบบ
/// - มีพื้น + ตามแถบเมนู = กรอบทึบเจาะตัวเลข (template ⇒ สีตามธีม) · มีพื้น + สี = กรอบสี ตัวเลขขาว
/// - กรอบเส้น / ไม่มีพื้น = ตัวเลขสีเดียวกับกรอบ
enum MenuIcon {
    static func make(text: String, style: IconStyle, color: IconColor) -> NSImage {
        let plain = style == .plain
        let font: NSFont = plain
            ? .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            : .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let measure = (text as NSString).size(withAttributes: [.font: font])
        let height: CGFloat = 16
        // ช่องว่างซ้ายขวาในกรอบ · เลขวันหลักเดียว/สองหลักใช้กรอบกว้างเท่าเดิม (20) ไม่ให้ไอคอนขยับ
        let boxW = plain ? ceil(measure.width) : max(20, ceil(measure.width) + 9)
        let size = NSSize(width: boxW + 2, height: height)

        let img = NSImage(size: size, flipped: false) { _ in
            let ink = color.nsColor ?? .black
            let box = NSRect(x: 1, y: 0.5, width: boxW, height: 15)
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let ts = (text as NSString).size(withAttributes: attrs)
            let at = NSPoint(x: box.midX - ts.width / 2, y: box.midY - ts.height / 2)

            switch style {
            case .filled:
                ink.setFill()
                NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
                if color.nsColor == nil {
                    // เจาะตัวเลขออก (โปร่ง เห็นสีแถบเมนู)
                    NSGraphicsContext.current?.compositingOperation = .destinationOut
                    (text as NSString).draw(at: at, withAttributes: attrs)
                    NSGraphicsContext.current?.compositingOperation = .sourceOver
                } else {
                    attrs[.foregroundColor] = NSColor.white
                    (text as NSString).draw(at: at, withAttributes: attrs)
                }
            case .outline:
                ink.setStroke()
                let p = NSBezierPath(roundedRect: box.insetBy(dx: 0.6, dy: 0.6), xRadius: 3.5, yRadius: 3.5)
                p.lineWidth = 1.2
                p.stroke()
                (text as NSString).draw(at: at, withAttributes: attrs)
            case .plain:
                (text as NSString).draw(at: at, withAttributes: attrs)
            }
            return true
        }
        img.isTemplate = color.nsColor == nil
        return img
    }
}
