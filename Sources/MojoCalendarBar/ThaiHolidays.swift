import Foundation

/// วันสำคัญไทยของวันหนึ่ง (key = ชื่ออังกฤษ ใช้เป็นคีย์คำแปลใน Localizable.xcstrings)
struct ThaiHoliday: Equatable {
    let key: String
    /// วันหยุดราชการ (ตัวเลขแดง) · false = วันสำคัญที่ไม่หยุด เช่น ลอยกระทง ออกพรรษา
    let isPublic: Bool
}

/// วันพระ + วันสำคัญ/วันหยุดไทย
/// ⚠️ ไม่รวมวันหยุดชดเชยและวันหยุดพิเศษที่ ครม. ประกาศเป็นปี ๆ (กติกาชดเชยมีข้อยกเว้น เดาเองแล้วผิด)
enum ThaiHolidays {
    struct DayInfo {
        let lunar: LunarDate
        let isHolyDay: Bool
        let holidays: [ThaiHoliday]
        var isPublicHoliday: Bool { holidays.contains { $0.isPublic } }
    }

    private static var cache: [Int: [Int: DayInfo]] = [:]   // ปี → (เดือน*100+วัน) → ข้อมูล

    static func info(year: Int, month: Int, day: Int) -> DayInfo? {
        if cache[year] == nil { cache[year] = build(year) }
        return cache[year]?[month * 100 + day]
    }

    static func info(_ date: Date, calendar: Calendar) -> DayInfo? {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return info(year: c.year!, month: c.month!, day: c.day!)
    }

    /// วันหยุดราชการที่วันตายตัว (ชุดปัจจุบัน ใช้ตั้งแต่ปี 2563/2020)
    private static let fixed: [Int: [String]] = [
        101: ["New Year’s Day"], 406: ["Chakri Day"], 413: ["Songkran"], 414: ["Songkran"], 415: ["Songkran"],
        501: ["Labour Day"], 504: ["Coronation Day"], 603: ["Queen Suthida’s Birthday"], 728: ["King’s Birthday"],
        812: ["Mother’s Day"], 1013: ["King Bhumibol Memorial Day"], 1023: ["Chulalongkorn Day"],
        1205: ["Father’s Day"], 1210: ["Constitution Day"], 1231: ["New Year’s Eve"],
    ]

    private static func build(_ year: Int) -> [Int: DayInfo] {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "UTC")!
        let start = g.date(from: DateComponents(year: year, month: 1, day: 1))!
        let days = g.range(of: .day, in: .year, for: start)!.count
        // ปีจุลศักราชที่มีวิสาขะ/อาสาฬหะของปีนี้ (เริ่มราวสงกรานต์) เป็นอธิกมาสไหม — มาฆะของปีนี้ก็ขยับตามปีนี้
        let leap = ThaiLunar.lunarDate(year: year, month: 6, day: 15).isLeapMonthYear

        var lunars: [(m: Int, d: Int, l: LunarDate)] = []
        for i in 0...days {   // +1 วัน ไว้ดูว่าวันสุดท้ายของปีเป็นวันสิ้นเดือนจันทรคติไหม
            let c = g.dateComponents([.year, .month, .day], from: g.date(byAdding: .day, value: i, to: start)!)
            lunars.append((c.month!, c.day!, ThaiLunar.lunarDate(year: c.year!, month: c.month!, day: c.day!)))
        }
        var out: [Int: DayInfo] = [:]
        for i in 0..<days {
            let (m, d, l) = lunars[i]
            let lastDayOfMonth = lunars[i + 1].l.day == 1
            var hs: [ThaiHoliday] = []
            if year >= 2020 { hs += (fixed[m * 100 + d] ?? []).map { ThaiHoliday(key: $0, isPublic: true) } }
            let eighth = leap ? l.isSecondEighth : (l.month == 8 && !l.isSecondEighth)
            if l.day == 15 && l.month == (leap ? 4 : 3) && m <= 4 { hs.append(ThaiHoliday(key: "Makha Bucha", isPublic: true)) }
            if l.day == 15 && l.month == (leap ? 7 : 6) && (4...6).contains(m) { hs.append(ThaiHoliday(key: "Visakha Bucha", isPublic: true)) }
            if l.day == 15 && eighth { hs.append(ThaiHoliday(key: "Asalha Bucha", isPublic: true)) }
            if l.day == 16 && eighth { hs.append(ThaiHoliday(key: "Buddhist Lent Day", isPublic: true)) }
            if l.day == 15 && l.month == 11 { hs.append(ThaiHoliday(key: "End of Buddhist Lent", isPublic: false)) }
            if l.day == 15 && l.month == 12 { hs.append(ThaiHoliday(key: "Loy Krathong", isPublic: false)) }
            // วันพระ: ขึ้น 8 · ขึ้น 15 · แรม 8 · วันสิ้นเดือน (แรม 14 เดือนขาด / แรม 15 เดือนเต็ม)
            let holy = l.day == 8 || l.day == 15 || l.day == 23 || lastDayOfMonth
            out[m * 100 + d] = DayInfo(lunar: l, isHolyDay: holy, holidays: hs)
        }
        return out
    }
}
