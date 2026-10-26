import Foundation

/// ระบบปี: พ.ศ. หรือ ค.ศ.
enum Era: String, CaseIterable, Identifiable {
    case buddhist, gregorian
    var id: String { rawValue }
    func label(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.buddhist, .th): return "พ.ศ."
        case (.gregorian, .th): return "ค.ศ."
        case (.buddhist, .en): return "BE"
        case (.gregorian, .en): return "AD"
        }
    }
}

/// ภาษาของหน้าจอ
enum Lang: String {
    case th, en
    var toggled: Lang { self == .th ? .en : .th }
    /// ป้ายบนปุ่มสลับ (บอกภาษาปัจจุบัน)
    var badge: String { self == .th ? "TH" : "EN" }

    var monthNames: [String] {
        self == .th
            ? ["มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน",
               "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"]
            : ["January", "February", "March", "April", "May", "June",
               "July", "August", "September", "October", "November", "December"]
    }
    var monthShort: [String] {
        self == .th
            ? ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
            : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    }
    var weekdayNames: [String] {
        self == .th
            ? ["อาทิตย์", "จันทร์", "อังคาร", "พุธ", "พฤหัสบดี", "ศุกร์", "เสาร์"]
            : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    }
    var weekdayShort: [String] {
        self == .th ? ["อา", "จ", "อ", "พ", "พฤ", "ศ", "ส"] : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    }

    // ข้อความบนหน้าจอ
    var today: String { self == .th ? "วันนี้" : "Today" }
    var quit: String { self == .th ? "ออก" : "Quit" }
    var showWeekNumbers: String { self == .th ? "แสดงเลขสัปดาห์" : "Show week numbers" }
    var launchAtLogin: String { self == .th ? "เปิดเองตอนเข้าเครื่อง" : "Open at login" }
    var copyShort: String { self == .th ? "คัดลอกวันที่แบบสั้น" : "Copy short date" }
    var help: String { self == .th ? "ช่วยเหลือ" : "Help" }
    var website: String { self == .th ? "เว็บไซต์ Mojozoft" : "Mojozoft website" }
    /// หน้าเว็บ mojozoft.com ตามภาษา (อังกฤษอยู่ใต้ /en/)
    func siteURL(_ path: String) -> URL {
        URL(string: "https://mojozoft.com/" + (self == .th ? "" : "en/") + path)!
    }
    var formatHelp: String { self == .th ? "กดเพื่อเปลี่ยนรูปแบบ" : "Click to change format" }
    var switchHelp: String { self == .th ? "Switch to English" : "เปลี่ยนเป็นภาษาไทย" }
    func copyFull(_ era: Era) -> String { self == .th ? "คัดลอกวันที่ (\(era.label(self)))" : "Copy date (\(era.label(self)))" }
    func daysAway(_ n: Int) -> String {
        if self == .th { return n > 0 ? "อีก \(n) วัน" : "ผ่านมาแล้ว \(-n) วัน" }
        let d = abs(n) == 1 ? "day" : "days"
        return n > 0 ? "In \(n) \(d)" : "\(-n) \(d) ago"
    }
}

/// ตัวช่วยจัดรูปแบบวันที่
/// คำนวณวันในปฏิทินด้วย Gregorian เสมอ (เดือน/วันตรงกันทั้งสองระบบ) แล้วค่อยแปลงปีตอนแสดงผล
/// ⇒ ไม่ต้องพึ่ง Calendar(.buddhist) ซึ่งตีความปีที่ป้อนเข้าต่างกัน
enum ThaiDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "th_TH")
        c.timeZone = .current
        c.firstWeekday = 1 // อาทิตย์ (แบบปฏิทินไทยทั่วไป)
        return c
    }()

    static func year(_ date: Date, era: Era) -> Int {
        let y = calendar.component(.year, from: date)
        return era == .buddhist ? y + 543 : y
    }

    /// จำนวนรูปแบบหัวเดือน (กดที่หัวเพื่อวนเปลี่ยน)
    static let monthTitleFormatCount = 4

    /// 0 "ตุลาคม 2569" · 1 "ตุลาคม พ.ศ. 2569" · 2 "ต.ค. 69" · 3 "10/2569"
    static func monthTitle(_ date: Date, era: Era, lang: Lang, format: Int = 0) -> String {
        let m = calendar.component(.month, from: date), y = year(date, era: era)
        switch format % monthTitleFormatCount {
        case 1:
            return lang == .th ? "\(lang.monthNames[m - 1]) \(era.label(lang)) \(y)"
                               : "\(lang.monthNames[m - 1]) \(y) \(era.label(lang))"
        case 2: return "\(lang.monthShort[m - 1]) \(String(format: "%02d", y % 100))"
        case 3: return "\(m)/\(y)"
        default: return "\(lang.monthNames[m - 1]) \(y)"
        }
    }

    /// "วันพุธที่ 21 ตุลาคม พ.ศ. 2569" / "Wednesday, 21 October 2569 BE"
    static func fullDate(_ date: Date, era: Era, lang: Lang) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let wd = lang.weekdayNames[c.weekday! - 1], mo = lang.monthNames[c.month! - 1], y = year(date, era: era)
        return lang == .th
            ? "วัน\(wd)ที่ \(c.day!) \(mo) \(era.label(lang)) \(y)"
            : "\(wd), \(c.day!) \(mo) \(y) \(era.label(lang))"
    }

    /// "21 ต.ค. 69" / "21 Oct 69" (ปีสองหลักตามระบบที่เลือก)
    static func shortDate(_ date: Date, era: Era, lang: Lang) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.day!) \(lang.monthShort[c.month! - 1]) \(String(format: "%02d", year(date, era: era) % 100))"
    }

    /// วันในกริดของเดือน (6 สัปดาห์ × 7 วัน = 42 ช่อง เริ่มวันอาทิตย์)
    static func gridDays(for month: Date) -> [Date] {
        let cal = calendar
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: first) // 1 = อาทิตย์
        let offset = (weekday - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first)!
        return (0..<42).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    static func weekOfYear(_ date: Date) -> Int {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = .current
        return iso.component(.weekOfYear, from: date)
    }
}
