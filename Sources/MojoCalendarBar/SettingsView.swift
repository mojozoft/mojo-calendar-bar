import SwiftUI
import AppKit

/// หน้าต่างตั้งค่า = NSWindow ของเราเอง (ไม่ใช้ SwiftUI `Settings` scene)
/// ⚠️ `openSettings()` จาก MenuBarExtra ในแอป LSUIElement กดแล้วเงียบ ไม่เปิดหน้าต่าง (เจอ 16 พ.ย. 69 · macOS 27)
///    และ TabView นอก Settings scene ไม่ได้แท็บแบบแถบเครื่องมือ ⇒ ทำแถบแท็บเอง
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = .preferredContentSize // เปลี่ยนแท็บแล้วหน้าต่างสูง/เตี้ยตามเนื้อหา
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        // แอปแถบเมนูต้อง activate เอง ไม่งั้นหน้าต่างไปอยู่หลังแอปอื่น
        // ⚠️ กดจากปุ่มใน popover: popover กำลังปิดตัวในจังหวะเดียวกัน ⇒ makeKeyAndOrderFront เฉย ๆ บางทีไม่ขึ้น
        //    (⌘, ขึ้นแต่คลิกเฟืองไม่ขึ้น · 16 พ.ย. 69) ⇒ orderFrontRegardless + ทำซ้ำรอบถัดไป
        let bring = {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
        bring()
        DispatchQueue.main.async(execute: bring)
    }

    static func setTitle(_ title: String) { window?.title = title }
}

/// แถบแท็บบน + กลุ่มมุมมนแบบ System Settings
/// ค่าทุกตัวเป็น @AppStorage คีย์เดียวกับ CalendarView/App ⇒ เปลี่ยนแล้วปฏิทินและไอคอนเปลี่ยนทันที
struct SettingsView: View {
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""
    @State private var tab = Tab.general

    enum Tab: CaseIterable {
        case general, icon, thai, about
        var key: String {
            switch self {
            case .general: "General"
            case .icon: "Icon"
            case .thai: "Thai calendar"
            case .about: "About"
            }
        }
        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .icon: "menubar.rectangle"
            case .thai: "moon.stars"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        let t = SettingsContext(langRaw: langRaw, eraRaw: eraRaw).t
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { item in
                    TabButton(title: t(item.key), symbol: item.symbol, selected: item == tab) { tab = item }
                }
            }
            .padding(.bottom, 8)
            Divider()
            Group {
                switch tab {
                case .general: GeneralSettings()
                case .icon: IconSettings()
                case .thai: ThaiSettings()
                case .about: AboutSettings()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 500)
        .onAppear { SettingsWindow.setTitle(t(tab.key)) }
        .onChange(of: tab) { _, new in SettingsWindow.setTitle(t(new.key)) }
        .onChange(of: langRaw) { _, _ in
            SettingsWindow.setTitle(SettingsContext(langRaw: langRaw, eraRaw: eraRaw).t(tab.key))
        }
    }
}

/// ปุ่มแท็บ: ไอคอนบน ชื่อล่าง · ที่เลือกอยู่ = สีเน้น + พื้นมน
private struct TabButton: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .frame(height: 28)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(minWidth: 70)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.primary.opacity(0.1) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false) // ไม่งั้นแท็บแรกมีกรอบโฟกัสฟ้าค้างตอนเปิดหน้าต่าง
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// ค่าที่ทุกแท็บใช้ร่วม: ภาษา/ระบบปีที่เลือก ⇒ ข้อความแปล + ชื่อศักราช
private struct SettingsContext {
    let text: DateText
    var t: Strings { text.strings }
    let era: Era

    init(langRaw: String, eraRaw: String) {
        let language = AppLanguage.resolve(langRaw)
        era = Era.resolve(eraRaw, language: language)
        text = DateText(language: language, era: era, firstWeekday: 0)
    }
}

// MARK: ทั่วไป
private struct GeneralSettings: View {
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""
    @AppStorage("firstWeekday") private var firstWeekday = 0
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        let c = SettingsContext(langRaw: langRaw, eraRaw: eraRaw)
        let t = c.t
        Form {
            Section(t("General")) {
                Toggle(t("Open at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }
                Picker(t("Language"), selection: $langRaw) {
                    Text(t("System language")).tag(AppLanguage.system)
                    Divider()
                    ForEach(AppLanguage.supported, id: \.self) { Text(AppLanguage.nativeName($0)).tag($0) }
                }
            }
            Section(t("Calendar")) {
                Picker(t("Year system"), selection: Binding(get: { c.era.rawValue }, set: { eraRaw = $0 })) {
                    ForEach(Era.allCases) { e in
                        Text(verbatim: "\(c.text.eraName(e)) (\(c.text.eraLabel(e)))").tag(e.rawValue)
                    }
                }
                Picker(t("Start week on"), selection: $firstWeekday) {
                    Text(t("Region default")).tag(0)
                    Divider()
                    ForEach([1, 2, 7], id: \.self) { Text(c.text.weekdayName($0)).tag($0) }
                }
                Toggle(t("Show week numbers"), isOn: $showWeekNumbers)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled } // ผู้ใช้อาจไปปิดใน System Settings มา
    }
}

// MARK: ไอคอนแถบเมนู
private struct IconSettings: View {
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""
    @AppStorage("iconStyle") private var iconStyle = 0
    @AppStorage("iconColor") private var iconColor = ""
    @AppStorage("iconContent") private var iconContent = 0

    var body: some View {
        let c = SettingsContext(langRaw: langRaw, eraRaw: eraRaw)
        let t = c.t
        let style = IconStyle(rawValue: iconStyle) ?? .filled
        let color = IconColor(rawValue: iconColor) ?? .system
        let label = c.text.menuBarText(Date(), content: IconContent(rawValue: iconContent) ?? .day)
        Form {
            Section(t("Preview")) {
                // แถบเมนูจำลอง สว่าง/มืด · ขยาย 2 เท่าให้เห็นชัด
                HStack(spacing: 12) {
                    ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                        MenuBarSample(image: MenuIcon.make(text: label, style: style, color: color), scheme: scheme)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            Section(t("Appearance")) {
                Picker(t("Style"), selection: $iconStyle) {
                    ForEach(IconStyle.allCases) { Text(t($0.nameKey)).tag($0.rawValue) }
                }
                LabeledContent(t("Color")) {
                    HStack(spacing: 7) {
                        ForEach(IconColor.allCases) { c in
                            ColorDot(color: c, selected: c == color) { iconColor = c.rawValue }
                                .help(t(c.nameKey))
                        }
                    }
                }
                Picker(t("Display"), selection: $iconContent) {
                    ForEach(IconContent.allCases) { Text(t($0.nameKey)).tag($0.rawValue) }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

/// แถบเมนูจำลองหนึ่งแถบ — template image ย้อมเป็นดำ/ขาวตามธีม
private struct MenuBarSample: View {
    let image: NSImage
    let scheme: ColorScheme

    var body: some View {
        let dark = scheme == .dark
        Image(nsImage: image)
            .renderingMode(image.isTemplate ? .template : .original)
            .resizable()
            .interpolation(.high)
            .frame(width: image.size.width * 2, height: image.size.height * 2)
            .foregroundStyle(dark ? Color.white : Color.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(dark ? Color(white: 0.16) : Color(white: 0.93))
            )
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
    }
}

/// จุดสีแบบตัวเลือกสีเน้นของ System Settings
private struct ColorDot: View {
    let color: IconColor
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(nsImage: color.swatch)
                .resizable()
                .frame(width: 16, height: 16)
                .padding(2)
                .overlay(Circle().strokeBorder(selected ? Color.primary.opacity(0.7) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.nameKey)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: ปฏิทินไทย
private struct ThaiSettings: View {
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""
    @AppStorage("showHolyDays") private var holyRaw = ""
    @AppStorage("showThaiHolidays") private var holidaysRaw = ""
    @AppStorage("showLunar") private var lunarRaw = ""

    var body: some View {
        let c = SettingsContext(langRaw: langRaw, eraRaw: eraRaw)
        let t = c.t
        // "" = ตามเครื่อง (ภาษาไทยหรืออยู่ไทย = เปิด) — กติกาเดียวกับ CalendarView
        let thaiDefault = c.text.language == "th" || Locale.current.region?.identifier == "TH"
        func flag(_ raw: Binding<String>) -> Binding<Bool> {
            Binding(get: { raw.wrappedValue.isEmpty ? thaiDefault : raw.wrappedValue == "1" },
                    set: { raw.wrappedValue = $0 ? "1" : "0" })
        }
        return Form {
            Section(t("Thai calendar")) {
                Toggle(t("Buddhist holy days"), isOn: flag($holyRaw))
                Toggle(t("Thai holidays"), isOn: flag($holidaysRaw))
                Toggle(t("Waxing and waning moon"), isOn: flag($lunarRaw))
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: เกี่ยวกับ
private struct AboutSettings: View {
    @AppStorage("lang") private var langRaw = AppLanguage.system
    @AppStorage("era") private var eraRaw = ""

    var body: some View {
        let c = SettingsContext(langRaw: langRaw, eraRaw: eraRaw)
        let t = c.t
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text(verbatim: "Mojo Calendar Bar").font(.title2.weight(.semibold))
            Text(t.format("Version %@", version)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(t("Help")) { NSWorkspace.shared.open(c.text.siteURL("support/")) }
                Button(t("Mojozoft website")) { NSWorkspace.shared.open(c.text.siteURL("")) }
            }
            .padding(.top, 4)
            Text(verbatim: "© 2026 Mojozoft").font(.footnote).foregroundStyle(.tertiary).padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
