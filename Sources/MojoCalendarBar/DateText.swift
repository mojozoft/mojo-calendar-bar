import Foundation

/// ระบบปี — ทุกตัวในนี้ใช้เดือน/วันแบบ Gregorian (ต่างกันแค่เลขปี + ชื่อศักราช)
/// ⇒ กริดคำนวณด้วย Gregorian เสมอ ส่วนระบบปีใช้แค่ตอนจัดรูปแบบข้อความ
/// ⛔ อย่าเพิ่มปฏิทินที่เดือนไม่ตรง Gregorian (จันทรคติจีน · ฮิจเราะห์ · เปอร์เซีย · ฮีบรู) ลงตรงนี้ — กริดจะผิด
enum Era: String, CaseIterable, Identifiable {
    case gregorian, buddhist, japanese, roc
    var id: String { rawValue }

    var calendarID: Calendar.Identifier {
        switch self {
        case .gregorian: .gregorian
        case .buddhist: .buddhist
        case .japanese: .japanese
        case .roc: .republicOfChina
        }
    }

    /// ญี่ปุ่น/ไต้หวัน: เลขปีไม่มีชื่อศักราชกำกับแล้วอ่านไม่ออก (เช่น "8年10月") ⇒ ใส่ศักราชทุกรูปแบบ
    var alwaysShowsEra: Bool { self == .japanese || self == .roc }

    /// ระบบปีประจำถิ่น — เป็นตัวเลือกที่สองบนปุ่มสลับ และค่าเริ่มต้นตอนติดตั้งใหม่
    static func regional(region: String?, language: String) -> Era? {
        switch region {
        case "TH": return .buddhist
        case "JP": return .japanese
        case "TW": return .roc
        default: return language == "th" ? .buddhist : nil
        }
    }

    /// ค่าที่เก็บไว้ ("" = ยังไม่เคยเลือก ⇒ ตามถิ่น หรือ ค.ศ.)
    static func resolve(_ stored: String, language: String) -> Era {
        Era(rawValue: stored) ?? regional(region: Locale.current.region?.identifier, language: language) ?? .gregorian
    }
}

/// ภาษาหน้าจอ — ข้อความแปลอยู่ใน Resources/Localizable.xcstrings · ชื่อเดือน/วันมาจากระบบ (ได้ทุกภาษา)
enum AppLanguage {
    /// ภาษาที่มีคำแปลครบ (ต้องตรงกับ Localizable.xcstrings และ CFBundleLocalizations ใน Info.plist)
    static let supported = ["en", "th", "ja", "ko", "zh-Hans", "zh-Hant", "de", "fr", "es", "pt-BR"]
    static let system = "system"

    /// ภาษาที่ใช้จริง: ที่เลือกไว้ หรือภาษาเครื่องที่ใกล้สุดที่เรามีคำแปล (ไม่มีเลย = อังกฤษ)
    static func resolve(_ stored: String) -> String {
        if supported.contains(stored) { return stored }
        return Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    /// ชื่อภาษาในภาษานั้นเอง ("ไทย" · "日本語" · "Français")
    static func nativeName(_ code: String) -> String {
        let l = Locale(identifier: code)
        return l.localizedString(forIdentifier: code)?.capitalized(with: l) ?? code
    }

    /// ป้ายบนปุ่มเลือกภาษา
    static func badge(_ code: String) -> String {
        switch code {
        case "zh-Hans": "简"
        case "zh-Hant": "繁"
        default: String(code.prefix(2)).uppercased()
        }
    }
}

/// ข้อความแปลของภาษาที่เลือก (เลือกภาษาในแอปเองได้ ไม่ผูกกับภาษาเครื่อง ⇒ เปิด <lang>.lproj ตรง ๆ)
struct Strings {
    let bundle: Bundle
    let locale: Locale

    init(language: String, locale: Locale) {
        self.locale = locale
        bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    func callAsFunction(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// รูปแบบที่มีตัวเลข/พหูพจน์ (stringsdict) — ต้องผ่าน NSString ไม่งั้นกฎพหูพจน์หาย
    func format(_ key: String, _ args: CVarArg...) -> String {
        let f = bundle.localizedString(forKey: key, value: key, table: nil) as NSString
        return NSString(format: f as String, locale: locale, arguments: getVaList(args)) as String
    }
}

/// การตั้งค่าที่มีผลกับการแสดงผล รวมไว้ที่เดียว (สร้างใหม่ทุกครั้งที่ค่าเปลี่ยน — ถูกมาก)
struct DateText {
    let language: String
    let era: Era
    let locale: Locale
    let calendar: Calendar   // Gregorian เสมอ · ใช้คำนวณกริด
    let strings: Strings

    /// - firstWeekday: 0 = ตามถิ่น · 1 อาทิตย์ … 7 เสาร์
    init(language: String, era: Era, firstWeekday: Int) {
        self.language = language
        self.era = era
        // ภาษาที่เลือก + ถิ่นของเครื่อง ⇒ en + TH = "21 October" · en + US = "October 21"
        let region = Locale.current.region?.identifier
        locale = Locale(identifier: region.map { "\(language)_\($0)" } ?? language)
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = .autoupdatingCurrent
        if (1...7).contains(firstWeekday) { c.firstWeekday = firstWeekday }
        calendar = c
        strings = Strings(language: language, locale: locale)
    }

    // MARK: จัดรูปแบบ (แม่แบบ ⇒ ระบบเรียงลำดับ/ใส่คำเชื่อมตามภาษาเอง)
    private static var cache: [String: DateFormatter] = [:]

    private func formatter(_ template: String, era: Era? = nil) -> DateFormatter {
        let e = era ?? self.era
        let key = "\(locale.identifier)|\(e.rawValue)|\(template)"
        if let f = Self.cache[key] { return f }
        // ⚠️ ต้องบอกระบบปีใน locale ด้วย (@calendar=) — ไม่งั้นภาษาอื่น + ถิ่นไทย (en_TH)
        //    ระบบถือว่าค่าเริ่มต้นคือ พ.ศ. แล้วแปะศักราชให้เองทุกรูปแบบ ("10/2026 A")
        let l = Locale(identifier: "\(locale.identifier)@calendar=\(e.rawValue)")
        var c = Calendar(identifier: e.calendarID)
        c.locale = l
        let f = DateFormatter()
        f.locale = l
        f.calendar = c
        f.setLocalizedDateFormatFromTemplate(template)
        Self.cache[key] = f
        return f
    }

    private func string(_ date: Date, _ template: String) -> String {
        let f = formatter(era.alwaysShowsEra && !template.contains("G") ? "G" + template : template)
        f.timeZone = .current
        return f.string(from: date)
    }

    /// ชื่อศักราชสั้น: พ.ศ. · ค.ศ. · BE · AD · 令和 · 民國
    func eraLabel(_ e: Era, at date: Date = Date()) -> String {
        formatter("G", era: e).string(from: date)
    }

    /// ชื่อเต็มของระบบปีในภาษาที่เลือก ("ปฏิทินพุทธ" · "Japanese Calendar")
    func eraName(_ e: Era) -> String {
        locale.localizedString(for: e.calendarID) ?? e.rawValue
    }

    /// จำนวนรูปแบบหัวเดือน (กดที่หัวเพื่อวนเปลี่ยน)
    static let monthTitleFormatCount = 4

    /// 0 "ตุลาคม 2569" · 1 "ตุลาคม พ.ศ. 2569" · 2 "ต.ค. 69" · 3 "10/2569"
    func monthTitle(_ date: Date, format: Int) -> String {
        string(date, ["MMMMy", "GMMMMy", "MMMyy", "My"][format % Self.monthTitleFormatCount])
    }

    /// "วันพุธที่ 21 ตุลาคม พ.ศ. 2569" · "Wednesday 21 October 2569 BE"
    func fullDate(_ date: Date) -> String { string(date, "GyMMMMEEEEd") }

    /// "21 ต.ค. 69"
    func shortDate(_ date: Date) -> String { string(date, "yyMMMd") }

    /// หัวคอลัมน์วัน เรียงตามวันเริ่มสัปดาห์ · weekday 1 = อาทิตย์
    /// ใช้ตัวย่อสุดถ้าไม่ซ้ำกัน (ไทย "อา จ อ" · ญี่ปุ่น "日 月") ไม่งั้นแบบสั้น (อังกฤษ S/T ซ้ำ ⇒ "Sun Mon")
    func weekdayHeaders() -> [(weekday: Int, text: String)] {
        let f = formatter("d")
        let tiny = f.veryShortStandaloneWeekdaySymbols ?? []
        let names = Set(tiny).count == 7 ? tiny : (f.shortStandaloneWeekdaySymbols ?? tiny)
        return (0..<7).map { i in
            let wd = (calendar.firstWeekday - 1 + i) % 7 + 1
            return (wd, names.count == 7 ? names[wd - 1] : "")
        }
    }

    /// ชื่อวันเต็ม (ใช้ในเมนูเลือกวันเริ่มสัปดาห์)
    func weekdayName(_ weekday: Int) -> String {
        formatter("d").standaloneWeekdaySymbols?[weekday - 1] ?? "\(weekday)"
    }

    /// วันในกริดของเดือน (6 สัปดาห์ × 7 วัน = 42 ช่อง เริ่มตามวันเริ่มสัปดาห์)
    func gridDays(for month: Date) -> [Date] {
        let cal = calendar
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first)!
        return (0..<42).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    /// เลขสัปดาห์ตามกติกาของถิ่น (ยุโรป = ISO · อเมริกา/ไทย = สัปดาห์ที่มี 1 ม.ค. คือสัปดาห์ 1)
    func weekOfYear(_ date: Date) -> Int { calendar.component(.weekOfYear, from: date) }

    /// "อีก 3 วัน" · "In 1 day" · "3日後"
    func daysAway(_ n: Int) -> String {
        n > 0 ? strings.format("In %lld days", n) : strings.format("%lld days ago", -n)
    }

    /// หน้าเว็บ mojozoft.com (ไทยอยู่ราก · ภาษาอื่นใช้หน้าอังกฤษใต้ /en/)
    func siteURL(_ path: String) -> URL {
        URL(string: "https://mojozoft.com/" + (language == "th" ? "" : "en/") + path)!
    }
}

extension Calendar {
    /// "วันนี้" ของเครื่อง (ไอคอนแถบเมนู · เช็คข้ามวัน) — เลขวันตรงกันทุกระบบปี
    static var localGregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .autoupdatingCurrent
        return c
    }
}
