import AppIntents
import Foundation

/// 快捷指令里可以直接调用的动作：
/// 自动化「收到信息」→ 运行「转发短信到 Bark」，把发件人 / 内容两个参数接上即可。
/// App「拦截」页里配的关键词规则会在动作执行时自动判定，命中拦截就不发请求。
struct ForwardSmsIntent: AppIntent {
    static var title: LocalizedStringResource = "转发短信到 Bark"
    static var description: IntentDescription {
        IntentDescription(
            "把发件人和短信内容推送到「短信转发」App 里配置的 Bark，并自动执行 App「拦截」页里的关键词规则（黑名单命中不推送 / 白名单未命中不推送）。配合「收到信息」自动化使用，参数接上快捷指令输入即可。",
            categoryName: "短信"
        )
    }

    /// 自动化后台运行，不把 App 拉到前台
    static var openAppWhenRun = false

    @Parameter(title: "发件人", description: "短信发件人，可为空", default: "")
    var sender: String

    @Parameter(title: "短信内容", description: "短信正文", default: "")
    var content: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let config = PushConfig.load()
        guard config.isReady else {
            record(.skipped, "还没填 Bark Device Key，先去 App 的「推送」页填好")
            return .result(dialog: "还没填写 Bark Key，先打开「短信转发」App 在「推送」页填好")
        }

        let cleanSender = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // ── 参数自愈：变量接错时自动纠正，不再依赖手工接线 100% 正确 ──
        var effectiveSender = cleanSender
        // 「发件人」里塞进了整条信息（超长或带换行）→ 那其实是正文
        if effectiveSender.contains("\n") || effectiveSender.count > 60 {
            cleanContent = cleanContent.isEmpty ? effectiveSender : cleanContent + "\n" + effectiveSender
            effectiveSender = ""
        }
        // 「短信内容」为空但「发件人」有字 → 多半两个接反了，把长的当正文
        if cleanContent.isEmpty, !effectiveSender.isEmpty {
            cleanContent = effectiveSender
            effectiveSender = ""
        }

        // ── 关键词拦截（与 App「拦截」页同一套判定逻辑）──
        let rules = RuleConfig.load()
        if rules.shouldBlock(cleanContent) {
            let hit = rules.matchedKeyword(in: cleanContent)
            let reason: String
            switch (rules.mode, hit) {
            case (.blacklist, .some(let kw)): reason = "命中黑名单关键词「\(kw)」"
            case (.blacklist, .none):         reason = "命中黑名单规则"
            case (.whitelist, .some):         reason = "内容不在白名单关键词范围内"
            case (.whitelist, .none):         reason = "没有命中任何白名单关键词"
            }

            // 留痕开关：推一条静默通知到指定分组，否则什么都不发
            if rules.blockedArchive == true {
                var archive = config
                archive.group = rules.archiveGroup
                archive.level = .passive
                archive.sound = .unspecified
                archive.callRepeat = 0
                archive.bodyTemplate = "⛔ 已拦截（\(reason)）\n发件人：{{发件人}}\n{{内容}}"
                if let url = archive.pushURL(body: archive.bodyTemplate
                    .replacingOccurrences(of: "{{发件人}}", with: effectiveSender.isEmpty ? "未知发件人" : effectiveSender)
                    .replacingOccurrences(of: "{{内容}}", with: cleanContent)
                    .replacingOccurrences(of: "{{时间}}", with: Self.timeText())) {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15
                    _ = try? await URLSession.shared.data(for: request)
                }
                record(.archived, reason + "；留痕发到「\(rules.archiveGroup)」分组")
                return .result(dialog: "已拦截并留痕到「\(rules.archiveGroup)」分组（\(reason)）")
            }
            record(.blocked, reason)
            return .result(dialog: "⛔ 已拦截，未推送（\(reason)）")
        }

        // ── 正常推送 ──
        let bodyText = config.bodyTemplate
            .replacingOccurrences(of: "{{发件人}}", with: effectiveSender.isEmpty ? "未知发件人" : effectiveSender)
            .replacingOccurrences(of: "{{内容}}", with: cleanContent)
            .replacingOccurrences(of: "{{时间}}", with: Self.timeText())

        guard let url = config.pushURL(body: bodyText) else {
            record(.failed, "推送地址拼接失败，检查「推送」页里的服务器地址")
            return .result(dialog: "推送地址拼接失败，检查「推送」页里的服务器地址")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        var received = Data()
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            received = data
        } catch {
            record(.failed, "网络请求失败：\(error.localizedDescription)")
            return .result(dialog: "网络请求失败：\(error.localizedDescription)")
        }

        let data = received

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = obj["code"] as? Int {
            if code == 200 {
                let okMessage = rules.isActive ? "已转发到 Bark（规则判定通过）" : "已转发到 Bark"
                record(.pushed, okMessage + Self.emptyHint(hasContent: !cleanContent.isEmpty))
                return .result(dialog: IntentDialog(stringLiteral: okMessage))
            }
            let message = obj["message"] as? String ?? "未知错误"
            record(.failed, "Bark 返回 \(code)：\(message)")
            return .result(dialog: "Bark 返回 \(code)：\(message)")
        }
        record(.pushed, "请求已发出，但返回内容无法解析" + Self.emptyHint(hasContent: !cleanContent.isEmpty))
        return .result(dialog: "请求已发出，但返回内容无法解析")
    }

    /// 内容为空说明自动化里「短信内容」参数没接到变量上，规则必然判不出来
    private static func emptyHint(hasContent: Bool) -> String {
        hasContent ? "" : "；⚠️ 短信内容为空，说明自动化里的变量没接上，关键词无法判定"
    }

    private func record(_ outcome: RunOutcome, _ detail: String) {
        // 记录的是动作实际收到的原始参数，方便从 App 里看出接线有没有错
        let rawSender = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var entry = RunLogEntry(sender: rawSender, content: rawContent, outcome: outcome, detail: detail)
        if rawSender != rawContent {
            entry.detail = detail + "｜收到：发件人=\(rawSender.isEmpty ? "空" : String(rawSender.prefix(20))) 内容=\(rawContent.isEmpty ? "空" : String(rawContent.prefix(30)))"
        }
        RunLog.append(entry)
    }

    private static func timeText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
