import SwiftUI

struct ConfigView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    connectionCard
                    styleCard
                    advancedCard
                    templateCard
                    linkCard
                    resetCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("推送配置")
            .keyboardDoneButton()
        }
    }

    // MARK: - 服务器与 Key

    private var connectionCard: some View {
        Card(title: "服务器与 Key", systemImage: "server.rack") {
            LabeledField(title: "服务器地址",
                         placeholder: "https://api.day.app",
                         text: $store.push.server,
                         keyboard: .URL,
                         footnote: "自建 Bark 就换成自己的域名，结尾不要带斜杠")

            LabeledField(title: "Device Key",
                         placeholder: "在 Bark App 首页复制",
                         text: $store.push.key,
                         footnote: "长按 Bark 首页的链接就能复制；只保存在本机，不会上传")

            HStack(spacing: 8) {
                StatusPill(ok: store.push.isReady,
                           text: store.push.isReady ? "可以推送" : "缺少 Device Key")
                Spacer()
                Button {
                    Task { await store.sendTest() }
                } label: {
                    Text(store.isSending ? "发送中…" : "测试推送")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!store.push.isReady || store.isSending)
            }
        }
    }

    // MARK: - 通知样式

    private var styleCard: some View {
        Card(title: "通知样式", systemImage: "bell") {
            LabeledField(title: "通知标题",
                         placeholder: "📩 新短信",
                         text: $store.push.title)

            LabeledField(title: "分组",
                         placeholder: "短信",
                         text: $store.push.group,
                         footnote: "Bark 列表里按分组归类，方便一眼筛出短信")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("中断级别")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("中断级别", selection: $store.push.level) {
                        ForEach(PushLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Text(store.push.level.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("提示音")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("提示音", selection: $store.push.sound) {
                    ForEach(PushSound.allCases) { sound in
                        Text(sound.title).tag(sound)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("重复响铃")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(value: $store.push.callRepeat, in: 0...5) {
                    Text(store.push.callRepeat == 0 ? "不重复" : "\(store.push.callRepeat) 次")
                        .font(.caption.weight(.medium))
                }
                .fixedSize()
            }
        }
    }

    // MARK: - 高级

    private var advancedCard: some View {
        Card(title: "高级", systemImage: "slider.horizontal.3") {
            LabeledField(title: "通知图标 URL",
                         placeholder: "https://…/icon.png（可留空）",
                         text: $store.push.icon,
                         keyboard: .URL)

            LabeledField(title: "点击通知跳转到",
                         placeholder: "https://…（可留空）",
                         text: $store.push.clickURL,
                         keyboard: .URL,
                         footnote: "可填 shortcuts:// 直接回到快捷指令")

            VStack(spacing: 0) {
                Toggle(isOn: $store.push.isArchive) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("保存到 Bark 历史").font(.footnote.weight(.medium))
                        Text("事后还能在 App 里翻到这条短信").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                Divider().opacity(0.5)

                Toggle(isOn: $store.push.autoCopy) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("自动复制正文").font(.footnote.weight(.medium))
                        Text("收到后直接粘到别处，适合抄验证码").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 正文模板

    private var templateCard: some View {
        Card(title: "正文模板",
             subtitle: "这就是快捷指令里「文本」动作要填的内容，{{发件人}} 和 {{内容}} 到时候换成变量。",
             systemImage: "text.alignleft") {
            TextField("正文模板", text: $store.push.bodyTemplate, axis: .vertical)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(3...8)
                .padding(11)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                CopyChip(text: store.push.bodyTemplate, note: "正文模板已复制")
                Spacer()
                Text("支持 {{发件人}} / {{内容}} / {{时间}}")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 生成的链接

    private var linkCard: some View {
        Card(title: "拼好的推送链接",
             subtitle: "示例正文已经填进去了，可以直接发给别人验证。",
             systemImage: "link") {
            CodeBlock(text: store.pushURLString,
                      placeholder: "填好 Device Key 后这里会出现完整链接")
            HStack {
                CopyChip(text: store.pushURLString, label: "复制链接", note: "推送链接已复制")
                Spacer()
            }
        }
    }

    // MARK: - 重置

    private var resetCard: some View {
        Card {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Text("恢复默认推送配置")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.red.opacity(0.10))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .alert("恢复默认配置？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) { store.clearPushConfig() }
            } message: {
                Text("服务器地址、Device Key、标题等会回到初始值，本机已填的内容会丢失。")
            }
        }
    }
}
