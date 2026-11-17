import Foundation
import UIKit
import Combine

@MainActor
final class AppStore: ObservableObject {

    @Published var push: PushConfig { didSet { save() } }
    @Published var rules: RuleConfig { didSet { save() } }

    @Published private(set) var isSending = false
    @Published var toast: String?

    private let defaults = UserDefaults.standard
    private enum StorageKey {
        static let push  = PushConfig.storageKey
        static let rules = "smsbark.rules.v1"
    }

    init() {
        push  = Self.decode(PushConfig.self, key: StorageKey.push) ?? PushConfig()
        rules = Self.decode(RuleConfig.self, key: StorageKey.rules) ?? RuleConfig()
    }

    // MARK: - 持久化

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// 编码放后台线程做，避免每次按键都卡主线程（否则连续输入会卡顿、掉字）
    private func save() {
        let pushSnapshot = push
        let rulesSnapshot = rules
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(pushSnapshot) {
                self.defaults.set(data, forKey: StorageKey.push)
            }
            if let data = try? JSONEncoder().encode(rulesSnapshot) {
                self.defaults.set(data, forKey: StorageKey.rules)
            }
        }
    }

    // MARK: - 示例正文

    /// 用示例数据填充正文模板，用于预览和测试推送
    var sampleBody: String {
        push.bodyTemplate
            .replacingOccurrences(of: "{{发件人}}", with: "1069 8888 1234")
            .replacingOccurrences(of: "{{内容}}", with: "【招商银行】您账户 1234 于 11月13日 23:30 完成交易 198.00 元。")
            .replacingOccurrences(of: "{{时间}}", with: Self.timeText())
    }

    /// 快捷指令里「文本」动作应该填的内容
    var bodyTemplateForShortcut: String { push.bodyTemplate }

    var pushURLString: String {
        push.pushURL(body: sampleBody)?.absoluteString ?? ""
    }

    static func timeText() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date())
    }

    // MARK: - 剪贴板

    func copy(_ text: String, note: String = "已复制") {
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        toast = note
    }

    // MARK: - 测试推送

    func sendTest() async {
        guard !isSending else { return }
        guard push.isReady else {
            toast = "先在「推送」页填写 Device Key"
            return
        }

        let body = push.bodyTemplate
            .replacingOccurrences(of: "{{发件人}}", with: "10086")
            .replacingOccurrences(of: "{{内容}}", with: "测试推送：看到这条说明配置成功")
            .replacingOccurrences(of: "{{时间}}", with: Self.timeText())

        guard let url = push.pushURL(body: body) else {
            toast = "推送地址拼接失败，检查服务器地址"
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)

            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = obj["code"] as? Int {
                if code == 200 {
                    toast = "已发送，去另一台 iPhone 看看"
                } else {
                    let msg = obj["message"] as? String ?? "未知错误"
                    toast = "Bark 返回 \(code)：\(msg)"
                }
            } else {
                toast = "请求已发出，但返回内容无法解析"
            }
        } catch {
            toast = "发送失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 重置

    func clearPushConfig() {
        push = PushConfig()
        toast = "已恢复默认推送配置"
    }

    func clearRules() {
        rules = RuleConfig()
        toast = "已清空拦截规则"
    }
}
