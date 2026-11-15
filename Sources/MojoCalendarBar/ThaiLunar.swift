import Foundation

// จันทรคติไทย (จุลศักราช · ตามหลักสุริยยาตร์) — port จาก pythaidate 0.2.0 (CsDate/LSYear)
// Copyright (c) Mark Hollow · MIT License (ดู THIRD_PARTY_NOTICES.md)
// ⛔ ห้ามแก้ตัวเลข/ตารางด้วยมือ — ตรวจเทียบ Python ทุกวันปี 1900–2100 แล้ว (ดู README §จันทรคติ)
//    คำนวณได้เฉพาะวันพระแบบมหานิกาย (ปฏิทินทั่วไป) · ธรรมยุต (ปักขคณนา) บางวันต่าง 1 วัน

/// วันทางจันทรคติ
struct LunarDate: Equatable {
    /// เดือน 1–12 (1 = อ้าย · 2 = ยี่)
    let month: Int
    /// เดือน 8 หลัง (ปีอธิกมาสมีเดือน 8 สองหน)
    let isSecondEighth: Bool
    /// วันในเดือน 1–30 (1–15 = ขึ้น · 16+ = แรม)
    let day: Int
    /// ปีนี้มีเดือน 8 สองหน
    let isLeapMonthYear: Bool

    var isWaxing: Bool { day <= 15 }
    /// เลขค่ำ (ขึ้น 1–15 · แรม 1–15)
    var phaseDay: Int { isWaxing ? day : day - 15 }
}

enum ThaiLunar {
    // ── ค่าคงที่ (pythaidate/constants.py) ──
    private static let daysIn800Years = 292207
    private static let timeUnitsIn1Day = 800
    private static let epochOffset = 373
    private static let csJulianDayOffset = 1954167

    private enum CalType { case a, b, c, cLower }  // A ปกติ 354 · B อธิกวาร 355 · C อธิกมาส 384

    private struct LSYear {
        var offset = false
        var horakhun: Int
        var tithi: Int
        var langsak: Int
        var nyd: Int
        var nextNyd: Int
        var leapday: Bool
        var calType: CalType
        var offsetDays = 0

        init(_ year: Int) {
            horakhun = (year * daysIn800Years + epochOffset) / timeUnitsIn1Day + 1
            let kammacapon = timeUnitsIn1Day - (year * daysIn800Years + epochOffset) % timeUnitsIn1Day
            let avoQuot = (horakhun * 11 + 650) / 692
            var avoman = (horakhun * 11 + 650) % 692
            if avoman == 0 { avoman = 692 }
            tithi = (avoQuot + horakhun) % 30
            if avoman == 692 { tithi -= 1 }
            let weekday = horakhun % 7

            let horakhun1 = ((year + 1) * daysIn800Years + epochOffset) / timeUnitsIn1Day + 1
            let quot1 = (horakhun1 * 11 + 650) / 692
            let tithi1 = (quot1 + horakhun1) % 30

            langsak = max(1, tithi)
            var n = langsak
            if n < 6 { n += 29 }
            nyd = (weekday - n + 1 + 35) % 7

            leapday = kammacapon <= 207

            var t: CalType = .a
            if tithi > 24 || tithi < 6 { t = .c }
            if tithi == 25 && tithi1 == 5 { t = .a }
            if (leapday && avoman <= 126) || (!leapday && avoman <= 137) { t = (t != .c) ? .b : .cLower }
            calType = t

            switch t {
            case .a: nextNyd = (nyd + 4) % 7
            case .b: nextNyd = (nyd + 5) % 7
            case .c, .cLower: nextNyd = (nyd + 6) % 7
            }
        }
    }

    private static func year0(_ year: Int) -> LSYear {
        var y = (-2...2).map { LSYear(year + $0) }
        for i in 0..<5 where y[2].tithi == 24 && y[3].tithi == 6 {
            y[i].calType = .c
            y[i].nextNyd = (y[i].nextNyd + 2) % 7
        }
        for i in 1...3 where y[i].calType == .cLower {
            let j = y[i].nyd == y[i - 1].nextNyd ? 1 : -1
            y[i + j].calType = .b
            y[i + j].nextNyd = (y[i + j].nextNyd + 1) % 7
        }
        for i in 1...3 where y[i - 1].nextNyd != y[i].nyd && y[i].nextNyd != y[i + 1].nyd {
            y[i].offset = true
            y[i].langsak += 1
            y[i].nyd = (y[i].nyd + 6) % 7
            y[i].nextNyd = (y[i].nextNyd + 6) % 7
        }
        for i in 0..<5 where y[i].calType == .cLower { y[i].calType = .c }
        var r = y[2]
        r.offsetDays = r.langsak
        if r.offsetDays < 6 + (r.offset ? 1 : 0) { r.offsetDays += 29 }
        return r
    }

    // pythaidate LUNAR_MONTHS: 13 = 8 แรก (ปีอธิกมาส) · 14 = 8 หลัง (88) · 15/16 = เดือน 5/6 ปลายปี
    private static let lunarMonths = [0, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 8, 88, 15, 16]
    private static let monthTable: [CalType: [(Int, Int)]] = [
        .a: [(383, 16), (354, 15), (324, 12), (295, 11), (265, 10), (236, 9), (206, 8), (177, 7), (147, 6), (118, 5), (88, 4), (59, 3), (29, 2)],
        .b: [(384, 16), (355, 15), (325, 12), (296, 11), (266, 10), (237, 9), (207, 8), (178, 7), (148, 6), (119, 5), (89, 4), (59, 3), (29, 2)],
        .c: [(384, 15), (354, 12), (325, 11), (295, 10), (266, 9), (236, 8), (207, 7), (177, 6), (148, 5), (118, 14), (88, 13), (59, 3), (29, 2)],
    ]

    /// (จุลศักราช, เดือนดิบแบบ pythaidate, วัน, ปีนั้นเป็นอธิกมาส)
    static func raw(julianDay jd: Int) -> (year: Int, month: Int, day: Int, leapMonth: Bool) {
        let hk = jd - csJulianDayOffset
        var year = (hk * 800 - 373) / daysIn800Years
        var days: Int
        if hk % daysIn800Years == 95333 {
            year -= 1
            days = 365
        } else {
            days = hk - year0(year).horakhun
        }
        var y0 = year0(year)
        var diy = 365 + (y0.leapday ? 1 : 0)
        while days > diy {
            year += 1
            days -= diy
            y0 = year0(year)
            diy = 365 + (y0.leapday ? 1 : 0)
        }
        var d = y0.offsetDays + days
        var month = lunarMonths[1]
        for (a, b) in monthTable[y0.calType == .cLower ? .c : y0.calType]! where d > a {
            d -= a
            month = lunarMonths[b]
            break
        }
        return (year, month, d, y0.calType == .c || y0.calType == .cLower)
    }

    /// Julian Day Number ของวันที่ Gregorian (เที่ยงวัน)
    static func julianDay(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    static func lunarDate(year: Int, month: Int, day: Int) -> LunarDate {
        let r = raw(julianDay: julianDay(year: year, month: month, day: day))
        // เดือน 5/6 ที่ตกปลายปีจุลศักราช (15/16) คือเดือน 5/6 ของรอบถัดไป · อธิกมาสของ "ปีถัดไป" ไม่เกี่ยวกับเดือนนี้
        let m = r.month == 88 ? 8 : (r.month > 12 ? r.month - 10 : r.month)
        return LunarDate(month: m, isSecondEighth: r.month == 88, day: r.day, isLeapMonthYear: r.leapMonth)
    }

    static func lunarDate(_ date: Date, calendar: Calendar) -> LunarDate {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return lunarDate(year: c.year!, month: c.month!, day: c.day!)
    }
}
