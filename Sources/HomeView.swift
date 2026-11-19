import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var latestLogs: [RunLogEntry] = []

    private var maskedKey: String {
        let key = store.push.trimmedKey
        if key.isEmpty { return "未填写" }
        if key.count <= 8 { return key }
        return String(key.prefix(4)) + "••••" + String(key.suffix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    activityCard
                    overviewCard
                    testCard
                    ruleCard
                    flowCard
                    limitCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SmsBark")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { latestLogs = RunLog.load() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { latestLogs = RunLog.load() }
            }
        }
    }

    // MARK: - 最近一次动作（排查用）

    private var activityCard: some View {
        Card(title: "最近一次动作",
             subtitle: "快捷指令每跑一次「转发短信到 Bark」，这里就会刷新。一条记录都没有 = 自动化根本没调到这个动作。",
             systemImage: "waveform.path.ecg") {

            if let latest = latestLogs.first {
                let tint: Color = latest.outcome.isBlocked ? .orange : (latest.outcome.isBad ? .red : .green)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: latest.outcome.symbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(tint)
                        Text(latest.outcome.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                        Spacer(minLength: 0)
                        Text(Self.relative(latest.date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(latest.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !latest.content.isEmpty || !latest.sender.isEmpty {
                        Text("\(latest.sender.isEmpty ? "未知发件人" : latest.sender)：\(latest.content)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .padding(.top, 1)
                    Text("还从没执行过。检查三件事：自动化开关是否绿色、触发器左边小圆点是否绿色、「运行前询问」是否关闭。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    latestLogs = RunLog.load()
                    store.toast = "已刷新"
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if latestLogs.count > 1 {
                    Text("共 \(latestLogs.count) 条记录，全部在「拦截」页")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86_400 { return "\(seconds / 3600) 小时前" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    // MARK: - 概览

    private var overviewCard: some View {
        Card(title: "当前配置", systemImage: "dot.radiowaves.left.and.right") {
            HStack(spacing: 8) {
                StatusPill(ok: store.push.isReady,
                           text: store.push.isReady ? "已就绪" : "待配置")
                Spacer()
            }

            VStack(spacing: 0) {
                infoRow("服务器", store.push.normalizedServer)
                Divider().opacity(0.5)
                infoRow("Device Key", maskedKey)
                Divider().opacity(0.5)
                infoRow("分组", store.push.group.isEmpty ? "未设置" : store.push.group)
                Divider().opacity(0.5)
                infoRow("中断级别", store.push.level.title)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 7)
    }

    // MARK: - 测试

    private var testCard: some View {
        Card(title: "验证链路",
             subtitle: "测试推送会真的发到你的其他设备，用来确认 Key 和网络都正常。",
             systemImage: "bolt.horizontal") {
            Button {
                Task { await store.sendTest() }
            } label: {
                HStack(spacing: 8) {
                    if store.isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .semibold))
                    }
                    Text(store.isSending ? "正在发送…" : "发送一条测试推送")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isSending)

            Button {
                store.copy(store.pushURLString, note: "推送链接已复制")
            } label: {
                Text("复制推送链接")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 规则摘要

    private var ruleCard: some View {
        Card(title: "拦截规则", systemImage: "hand.raised") {
            if store.rules.isActive {
                HStack(spacing: 8) {
                    StatusPill(ok: true,
                               text: store.rules.mode == .blacklist ? "黑名单生效中" : "白名单生效中")
                    Text("\(store.rules.keywords.count) 个关键词")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                NoteText(text: store.rules.mode.detail)
            } else {
                NoteText(text: "还没有设置关键词，所有短信都会照常转发。去「拦截」页可以屏蔽营销短信，或只放行验证码。",
                         systemImage: "hand.raised.slash")
            }
        }
    }

    // MARK: - 链路图

    private var flowCard: some View {
        Card(title: "它是怎么跑起来的", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 10) {
                flowRow(1, "iPhone 收到短信", "系统短信 App", "message.fill")
                flowRow(2, "快捷指令触发", "「收到信息」自动化，调起本 App 的动作", "bolt.fill")
                flowRow(3, "动作自动判定拦截规则", "命中黑名单 / 未命中白名单就不发请求", "hand.raised.fill")
                flowRow(4, "推送到 Bark", "另一台设备立刻收到", "bell.badge.fill")
            }
        }
    }

    private func flowRow(_ index: Int, _ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote.weight(.medium))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 边界说明

    private var limitCard: some View {
        Card(title: "先说清楚一件事", systemImage: "exclamationmark.triangle") {
            NoteText(text: "iOS 不允许任何第三方 App 读取短信收件箱，这条转发链路必须由「快捷指令」触发。本 App 负责配置、拼链接、判定规则和验证，真正收到短信的那一刻由快捷指令接管。",
                     systemImage: "info.circle",
                     tint: .orange)
        }
    }
}
