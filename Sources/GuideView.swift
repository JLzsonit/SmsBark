import SwiftUI
import UIKit

struct GuideView: View {
    @EnvironmentObject private var store: AppStore

    struct Step {
        let title: String
        let detail: String
        let sub: [String]
        let icon: String
    }

    private let steps: [Step] = [
        Step(title: "打开快捷指令 → 点「自动化」→ 选「通知」",
             detail: "底部「自动化」→ 右上角 ＋ → 在触发列表里点「通知」→ 条件选「我收到来自 信息」。发件人留空＝所有短信都转发。",
             sub: [],
             icon: "bell.badge.fill"),
        Step(title: "添加操作：转发短信到 Bark",
             detail: "点「添加操作」→ 搜索「短信转发」→ 选本 App 提供的「转发短信到 Bark」。拦截页里配的关键词在这一步自动生效，不需要再加任何判断动作。",
             sub: [],
             icon: "square.and.arrow.down.fill"),
        Step(title: "点「发件人」和「短信内容」接变量",
             detail: "这是唯一容易点错的一步，两个参数各走同一条路径：",
             sub: [
                "① 点「发件人」框 → 在面板里点「快捷指令输入」",
                "② 轻点「输入快捷指令的信息」，会展开详细信息",
                "③ 类型选「通知」，再在「获取」里选「发件人」",
                "④ 点「短信内容」框，重复 ①②③，最后「获取」里选「正文」"
             ],
             icon: "variable"),
        Step(title: "关掉「运行前询问」→ 完成",
             detail: "把「运行前询问」（部分系统显示「运行前确认」）关掉，改成立即运行 → 右上角「完成」。从此收到短信自动转发，不用手动跑任何东西。",
             sub: [],
             icon: "checkmark.seal.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    introCard
                    oneTapCard
                    stepsCard
                    tipsCard
                    faqCard
                    footerCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("使用指引")
            .scrollDismissesKeyboard(.immediately)
            .keyboardDoneButton()
        }
    }

    // MARK: - 开场

    private var introCard: some View {
        Card(title: "整体思路", systemImage: "map") {
            NoteText(text: "iOS 没有开放短信读取接口，所以转发必须由快捷指令的自动化触发。好消息是：装好本 App 后，快捷指令里自带一个「转发短信到 Bark」动作，自动化只需 4 步就能搭完，不用再手动拼那些动作。",
                     systemImage: "info.circle",
                     tint: .orange)

            Button {
                if let url = URL(string: "shortcuts://create-automation") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("一键创建自动化（直接跳到创建页）", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 一键创建

    private var oneTapCard: some View {
        Card(title: "一键创建自动化",
             subtitle: "点下面的按钮会直接打开快捷指令的新建自动化页，剩下的点击照着下面清单来。",
             systemImage: "bolt.badge.plus") {

            Button {
                if let url = URL(string: "shortcuts://create-automation") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("去创建自动化", systemImage: "arrow.up.forward.app")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            NoteText(text: "为什么不能全自动建好？iOS 的硬限制：苹果没有开放“替用户创建自动化”的任何接口（触发器和动作都无法由 App 预填），任何 App 声称能全自动创建都是假的。这个按钮已经把路径缩到最短，剩下 4 步照着点：",
                     systemImage: "lock.shield",
                     tint: .orange)

            VStack(alignment: .leading, spacing: 4) {
                tap("① 自动化 → ＋ → 选「通知」→「我收到来自 信息」")
                tap("② 添加操作 → 搜「短信转发」→ 选「转发短信到 Bark」")
                tap("③ 发件人／短信内容 → 快捷指令输入 → 输入快捷指令的信息 → 类型「通知」→ 获取「发件人」/「正文」")
                tap("④ 关掉「运行前询问」→ 右上角「完成」")
            }
            .padding(11)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func tap(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 六步

    private var stepsCard: some View {
        Card(title: "四步搭完",
             subtitle: "装好本 App 后，快捷指令里能直接搜到「转发短信到 Bark」动作，照下面 4 步点完即可。",
             systemImage: "list.number") {

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 { Divider().opacity(0.4) }
                    HStack(alignment: .top, spacing: 11) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: step.icon)
                                    .font(.caption2)
                                    .foregroundStyle(Color.accentColor)
                                Text(step.title)
                                    .font(.footnote.weight(.semibold))
                            }
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if !step.sub.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(Array(step.sub.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.caption)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                }
            }

            HStack {
                CopyChip(text: stepsText, label: "复制步骤", note: "步骤已复制")
                Spacer()
            }
        }
    }

    private var stepsText: String {
        steps.enumerated().map { index, step in
            var text = "\(index + 1). \(step.title)：\(step.detail)"
            if !step.sub.isEmpty {
                text += "\n" + step.sub.joined(separator: "\n")
            }
            return text
        }.joined(separator: "\n")
    }

    // MARK: - 注意事项

    private var tipsCard: some View {
        Card(title: "容易踩的坑", systemImage: "exclamationmark.triangle") {
            tip("关键词拦截怎么生效？", "在 App 的「拦截」页配好关键词就行，「转发短信到 Bark」动作执行时会自动判定：黑名单命中 / 白名单未命中都不发请求，另一台 iPhone 不会有任何动静。快捷指令里不用加任何判断动作。")
            tip("拦截了却没生效？看运行记录", "「拦截」页最下面有「运行记录」：动作每跑一次都会写下收到什么、判了什么、有没有推。内容显示为空，就是自动化里的变量没接上；一条记录都没有，就是自动化没调到这个动作。")
            tip("别开「过滤未知发件人」", "被拦到「未知发件人」列表的信息通常不会触发自动化，转发会漏。")
            tip("只转发新短信", "自动化是事件触发，规则建好之前收到的短信不会补发。")
            tip("iMessage 也会触发", "只想要普通短信，就在条件里按发件人筛选。")
            tip("必须有网络", "短信刚到的那一刻没网，这次推送就丢了，短信本身还在手机上。")
        }
    }

    private func tip(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    // MARK: - FAQ

    private var faqCard: some View {
        Card(title: "常见问题", systemImage: "questionmark.bubble") {
            faq("想用关键词拦截？", "直接在 App 的「拦截」页配关键词，动作会自动判定，快捷指令里什么都不用加。只有不用本 App 动作、手动拼动作时，才需要拦截页生成的正则（见下一条）。")
            faq("手动拼动作的老办法（不用 App 动作）", "「获取快捷指令输入的详细信息」取发件人和内容 →「匹配文本」粘拦截页生成的正则 → 命中就「停止」→「文本」拼正文（{{发件人}}/{{内容}} 位置插变量）→「URL 编码」→「文本」贴推送链接 →「获取 URL 内容」GET。")
            faq("拦截了还想留记录怎么办？",
                "拦截页打开「拦截后留痕」，被拦的短信会推一条静默通知到指定分组，只进通知中心不响铃，事后还能翻。")
            faq("关键词填了却没拦住？",
                "先去「拦截」页最下面的「运行记录」看那条短信：①记录里「内容为空」→ 自动化里「短信内容」参数没接到「快捷指令输入 → 获取正文」上，规则判不出来；②记录是「已推送」→ 关键词和短信原文没对上（全角半角、多余空格，v1.3 起会自动归一化，但仍建议拿原文试）；③一条记录都没有 → 自动化根本没调用这个动作。")
            faq("参数里出现「输入快捷指令的信息」正常吗？",
                "正常，它就是「快捷指令输入」被轻点后的名字。轻点它之后会展开「类型」和「获取」两栏：类型选「通知」；「发件人」参数在「获取」里选「发件人」，「短信内容」参数在「获取」里选「正文」。注意：千万不要用键盘往参数框里打字，打进去的是固定文字，每条短信都会原样带上。")
            faq("能推到飞书、钉钉、企业微信吗？",
                "可以。App「推送」页把服务器地址换成对应机器人的 Webhook 就行。")
            faq("换手机了要重新配吗？",
                "Bark 的 Device Key 跟着 App 走，换机重装会变，改一下 Device Key 就行，其它配置会自动保存。")
        }
    }

    private func faq(_ question: String, _ answer: String) -> some View {
        DisclosureGroup {
            Text(answer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(question)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 7)
        .tint(.secondary)
    }

    // MARK: - 页脚

    private var footerCard: some View {
        VStack(spacing: 6) {
            Text("SmsBark 1.4.3")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text("纯本地运行 · 不采集任何数据 · 配置只存在这台设备")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
