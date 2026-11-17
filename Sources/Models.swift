import Foundation

// MARK: - 推送中断级别

enum PushLevel: String, CaseIterable, Identifiable, Codable {
    case active
    case timeSensitive
    case passive
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:        return "普通提醒"
        case .timeSensitive: return "时效性通知"
        case .passive:       return "静默"
        case .critical:      return "重要警告"
        }
    }

    var detail: String {
        switch self {
        case .active:        return "默认级别，横幅 + 提示音"
        case .timeSensitive: return "可穿透专注模式，短信转发建议用这个"
        case .passive:       return "只进通知中心，不点亮屏幕"
        case .critical:      return "需在 Bark 内额外授权，慎用"
        }
    }
}

// MARK: - 提示音

enum PushSound: String, CaseIterable, Identifiable, Codable {
    case bell
    case birdsong
    case electronic
    case horn
    case glass
    case synth
    case unspecified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bell:        return "bell · 清脆"
        case .birdsong:    return "birdsong · 鸟鸣"
        case .electronic:  return "electronic · 电子音"
        case .horn:        return "horn · 号角"
        case .glass:       return "glass · 玻璃"
        case .synth:       return "synth · 合成器"
        case .unspecified: return "不指定（跟随 Bark 设置）"
        }
    }

    var paramValue: String? {
        self == .unspecified ? nil : rawValue
    }
}

// MARK: - 拦截模式

enum RuleMode: String, CaseIterable, Identifiable, Codable {
    case blacklist
    case whitelist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blacklist: return "黑名单 · 命中就拦截"
        case .whitelist: return "白名单 · 只放行命中"
        }
    }

    var detail: String {
        switch self {
        case .blacklist: return "短信里出现任意一个关键词就拦下来，不推送到另一台 iPhone。"
        case .whitelist: return "只有出现关键词的短信才转发，其余全部拦掉。"
        }
    }
}

// MARK: - 推送配置

struct PushConfig: Codable {
    static let storageKey = "smsbark.push.v1"

    var server: String = "https://api.day.app"
    var key: String = ""
    var title: String = "📩 新短信"
    var group: String = "短信"
    var level: PushLevel = .timeSensitive
    var sound: PushSound = .bell
    var callRepeat: Int = 0
    var icon: String = ""
    var clickURL: String = ""
    var bodyTemplate: String = "发件人：{{发件人}}\n{{内容}}"
    var isArchive: Bool = true
    var autoCopy: Bool = false

    var normalizedServer: String {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s.isEmpty ? "https://api.day.app" : s
    }

    var trimmedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isReady: Bool { !trimmedKey.isEmpty }

    /// App Intents 等非视图环境直接读本机配置
    static func load() -> PushConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(PushConfig.self, from: data) {
            return config
        }
        return PushConfig()
    }

    /// 拼出 Bark 的路径式推送地址：{server}/{key}/{title}/{body}
    func pushURL(body: String) -> URL? {
        guard let encodedTitle = Self.encodeSegment(title),
              let encodedBody = Self.encodeSegment(body),
              var comps = URLComponents(string: normalizedServer) else {
            return nil
        }
        comps.percentEncodedPath = "/\(trimmedKey)/\(encodedTitle)/\(encodedBody)"

        var items: [URLQueryItem] = []
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedGroup.isEmpty { items.append(URLQueryItem(name: "group", value: trimmedGroup)) }
        items.append(URLQueryItem(name: "level", value: level.rawValue))
        if let soundValue = sound.paramValue { items.append(URLQueryItem(name: "sound", value: soundValue)) }
        if callRepeat > 0 { items.append(URLQueryItem(name: "call", value: String(callRepeat))) }
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIcon.isEmpty { items.append(URLQueryItem(name: "icon", value: trimmedIcon)) }
        let trimmedClick = clickURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedClick.isEmpty { items.append(URLQueryItem(name: "url", value: trimmedClick)) }
        if isArchive { items.append(URLQueryItem(name: "isArchive", value: "1")) }
        if autoCopy { items.append(URLQueryItem(name: "autoCopy", value: "1")) }

        comps.queryItems = items.isEmpty ? nil : items
        return comps.url
    }

    /// 严格按路径段编码，避免中文和斜杠把 URL 拆断
    private static func encodeSegment(_ text: String) -> String? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}

// MARK: - 拦截规则

struct RuleConfig: Codable {
    static let storageKey = "smsbark.rules.v1"

    var mode: RuleMode = .blacklist
    var keywords: [String] = []
    var caseInsensitive: Bool = false
    /// 拦截后是否还推一条静默通知留痕（可选，默认不推）
    var blockedArchive: Bool?
    /// 留痕通知的分组名
    var blockedGroup: String?

    var isActive: Bool { !keywords.isEmpty }

    /// App Intents 等非视图环境直接读本机规则
    static func load() -> RuleConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let rules = try? JSONDecoder().decode(RuleConfig.self, from: data) {
            return rules
        }
        return RuleConfig()
    }

    var archiveGroup: String {
        let g = blockedGroup?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return g.isEmpty ? "已拦截" : g
    }

    /// 本地判定：命中的关键词，没命中返回 nil
    func matchedKeyword(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let haystack = Self.normalize(text, caseInsensitive: caseInsensitive)
        guard !haystack.isEmpty else { return nil }
        return keywords.first { keyword in
            let needle = Self.normalize(keyword, caseInsensitive: caseInsensitive)
            return !needle.isEmpty && haystack.contains(needle)
        }
    }

    /// 全角转半角 + 去掉所有空白，避免「回Ｔ退订」匹配不到「回T退订」、
    /// 短信里插入的空格把关键词拆断这类问题。
    static func normalize(_ text: String, caseInsensitive: Bool) -> String {
        var s = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        s = s.components(separatedBy: .whitespacesAndNewlines).joined()
        if caseInsensitive { s = s.lowercased() }
        return s
    }

    /// 这条短信最终会不会被拦下来
    func shouldBlock(_ text: String) -> Bool {
        guard isActive else { return false }
        let hit = matchedKeyword(in: text) != nil
        return mode == .blacklist ? hit : !hit
    }

    /// 给快捷指令「匹配文本」动作用的正则
    var shortcutPattern: String {
        guard !keywords.isEmpty else { return "" }
        let escaped = keywords.map(Self.escapeRegex).joined(separator: "|")
        return (caseInsensitive ? "(?i)" : "") + "(?:" + escaped + ")"
    }

    private static func escapeRegex(_ text: String) -> String {
        let specials = Set("\\^$.|?*+()[]{}".map { $0 })
        var out = ""
        for ch in text {
            if specials.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }
}

// MARK: - 运行记录（排查用）

enum RunOutcome: String, Codable {
    case pushed
    case blocked
    case archived
    case failed
    case skipped

    var title: String {
        switch self {
        case .pushed:   return "已推送"
        case .blocked:  return "已拦截"
        case .archived: return "拦截·留痕"
        case .failed:   return "失败"
        case .skipped:  return "跳过"
        }
    }

    var symbol: String {
        switch self {
        case .pushed:   return "checkmark.circle.fill"
        case .blocked:  return "nosign"
        case .archived: return "tray.and.arrow.down.fill"
        case .failed:   return "exclamationmark.triangle.fill"
        case .skipped:  return "pause.circle.fill"
        }
    }

    var isBlocked: Bool { self == .blocked || self == .archived }
    var isBad: Bool { self == .failed || self == .skipped }
}

struct RunLogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var sender: String
    var content: String
    var outcome: RunOutcome
    var detail: String
}

/// 动作每次执行都留一条记录，App 里直接看到「收到的是什么、为什么被拦/没拦」
enum RunLog {
    static let storageKey = "smsbark.runlog.v1"
    static let limit = 80

    static func load() -> [RunLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([RunLogEntry].self, from: data) else {
            return []
        }
        return list
    }

    static func append(_ entry: RunLogEntry) {
        var list = load()
        list.insert(entry, at: 0)
        if list.count > limit { list = Array(list.prefix(limit)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - 常用词库

enum KeywordPreset: String, CaseIterable, Identifiable {
    case marketing
    case carrier
    case verify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marketing: return "营销广告词"
        case .carrier:   return "运营商推广"
        case .verify:    return "验证码 / 账单"
        }
    }

    var keywords: [String] {
        switch self {
        case .marketing:
            return ["退订", "回T退订", "回复TD", "拒收", "优惠", "促销", "特惠", "活动", "领取",
                    "抽奖", "秒杀", "红包", "限时", "折扣", "会员", "积分", "免息", "贷款", "中奖", "点击链接"]
        case .carrier:
            return ["流量包", "套餐", "宽带", "话费", "积分兑换", "提速", "试用", "问卷", "点击办理"]
        case .verify:
            return ["验证码", "校验码", "动态码", "确认码", "取件码", "快递", "账单", "消费", "转账", "预约"]
        }
    }

    /// 验证码类默认应该用白名单语义
    var suggestedMode: RuleMode? {
        self == .verify ? .whitelist : nil
    }
}
