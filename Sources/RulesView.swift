import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var store: AppStore

    @State private var draft: String = ""
    @State private var testText: String = "【某某商城】限时特惠，全场满300减100，回复TD退订。"
    @State private var logs: [RunLogEntry] = []
    @FocusState private var draftFocused: Bool

    private var rules: RuleConfig { store.rules }

    private var verdictBlocked: Bool {
        rules.shouldBlock(testText)
    }

    private var verdictKeyword: String? {
        rules.matchedKeyword(in: testText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    modeCard
                    keywordsCard
                    patternCard
                    testerCard
                    logCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("关键词拦截")
            .scrollDismissesKeyboard(.immediately)
            .keyboardDoneButton()
            .onAppear { logs = RunLog.load() }
        }
    }

    // MARK: - 模式

    private var modeCard: some View {
        Card(title: "拦截模式", systemImage: "hand.raised") {
            Picker("模式", selection: $store.rules.mode) {
                ForEach(RuleMode.allCases) { mode in
                    Text(mode == .blacklist ? "黑名单" : "白名单").tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(rules.mode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $store.rules.caseInsensitive) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("忽略大小写").font(.footnote.weight(.medium))
                    Text("只有英文关键词才需要").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)

            Divider().opacity(0.5)

            Toggle(isOn: Binding(
                get: { store.rules.blockedArchive ?? false },
                set: { store.rules.blockedArchive = $0 }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("拦截后留痕").font(.footnote.weight(.medium))
                    Text("被拦的短信也推一条静默通知到下面的分组，只进通知中心不响铃，事后可翻").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if store.rules.blockedArchive == true {
                TextField("留痕分组名，默认「已拦截」", text: Binding(
                    get: { store.rules.blockedGroup ?? "" },
                    set: { store.rules.blockedGroup = $0 }
                ))
                .font(.system(size: 14))
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - 关键词

    private var keywordsCard: some View {
        Card(title: "关键词",
             subtitle: rules.keywords.isEmpty
                ? "每行一个词的匹配方式就是「包含」，命中任意一个即生效。"
                : "共 \(rules.keywords.count) 个词，任意一个命中就按上面的模式处理。",
             systemImage: "text.magnifyingglass") {

            HStack(spacing: 8) {
                TextField("输入关键词，比如 退订", text: $draft)
                    .font(.system(size: 14))
                    .focused($draftFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: addDraft) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(canAdd ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(canAdd ? Color.white : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }

            if rules.keywords.isEmpty {
                emptyKeywords
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rules.keywords.enumerated()), id: \.offset) { index, keyword in
                        if index > 0 { Divider().opacity(0.4) }
                        keywordRow(keyword, index: index)
                    }
                }
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(KeywordPreset.allCases) { preset in
                        Button(preset.title) { apply(preset) }
                    }
                } label: {
                    Label("套用常用词库", systemImage: "square.stack.3d.up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }

                if !rules.keywords.isEmpty {
                    Button(role: .destructive) {
                        store.rules.keywords.removeAll()
                    } label: {
                        Text("全部清空")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.red.opacity(0.10))
                            .foregroundStyle(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyKeywords: some View {
        HStack(spacing: 9) {
            Image(systemName: "tray")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Text("还没有关键词，规则暂不生效，所有短信都会转发。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func keywordRow(_ keyword: String, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(keyword)
                .font(.system(size: 13.5))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if rules.caseInsensitive {
                Text("不区分大小写")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Button {
                store.rules.keywords.remove(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.red.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private var canAdd: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && !rules.keywords.contains(text)
    }

    private func addDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !rules.keywords.contains(text) {
            store.rules.keywords.append(text)
        }
        draft = ""
    }

    private func apply(_ preset: KeywordPreset) {
        for word in preset.keywords where !store.rules.keywords.contains(word) {
            store.rules.keywords.append(word)
        }
        if let mode = preset.suggestedMode {
            store.rules.mode = mode
        }
        store.toast = "已加入 \(preset.title) 词库"
    }

    // MARK: - 交给快捷指令的正则

    private var patternCard: some View {
        Card(title: "手动方案用的正则（可选）",
             subtitle: "用「转发短信到 Bark」动作时不需要这一项，规则在动作里自动生效；只有手动拼动作的老办法才要把它粘进「匹配文本」。",
             systemImage: "curlybraces") {

            CodeBlock(text: rules.shortcutPattern, placeholder: "添加关键词后这里会生成正则")

            HStack(spacing: 8) {
                CopyChip(text: rules.shortcutPattern, label: "复制正则", note: "正则已复制")
                Spacer(minLength: 0)
            }

            Divider().opacity(0.5)

            Text("动作顺序（插在推送请求之前）")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            CodeBlock(text: orderSkeleton)

            NoteText(text: "注意：这套手动判定只在你不用「转发短信到 Bark」动作时才需要；用动作的话，拦截页里的规则已经自动生效。")
        }
    }

    private var orderSkeleton: String {
        let condition = rules.mode == .blacklist ? "有任何值" : "没有任何值"
        return """
        1  匹配文本   输入 = [短信内容]
                     正则 = [上面那串]

        2  如果       [匹配结果] \(condition)
              → 停止此快捷指令

        3  ……下面才是推送动作
        """
    }

    // MARK: - 试一下

    private var testerCard: some View {
        Card(title: "试一下",
             subtitle: "粘一条短信进来，实时看会不会被拦。「转发短信到 Bark」动作用的就是这套判定。",
             systemImage: "testtube.2") {

            TextField("粘贴短信内容", text: $testText, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(3...7)
                .padding(11)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            verdictStrip
        }
    }

    private var verdictStrip: some View {
        let blocked = verdictBlocked
        let tint: Color = blocked ? .red : .green
        let trimmed = testText.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: blocked ? "nosign" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(stripTitle(blocked: blocked, empty: trimmed.isEmpty))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                Text(stripDetail(blocked: blocked))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stripTitle(blocked: Bool, empty: Bool) -> String {
        if empty { return "粘贴一条短信试试" }
        if !rules.isActive { return "会转发（规则未启用）" }
        return blocked ? "已拦截，不会推送" : "会推送到 Bark"
    }

    private func stripDetail(blocked: Bool) -> String {
        if !rules.isActive {
            return "还没有关键词，请求会照常发出。"
        }
        if let keyword = verdictKeyword {
            return blocked
                ? "命中关键词「\(keyword)」，请求根本不会发出。"
                : "命中关键词「\(keyword)」，按白名单规则放行。"
        }
        return blocked
            ? "没有命中任何白名单关键词，请求根本不会发出。"
            : "没有命中任何黑名单关键词，正常推送。"
    }

    // MARK: - 运行记录

    private var logCard: some View {
        Card(title: "运行记录",
             subtitle: "动作每跑一次都会留一条：收到的是什么、为什么被拦、有没有推出去。排查「明明有关键词却还是收到」就看这里。",
             systemImage: "clock.arrow.circlepath") {

            if logs.isEmpty {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "tray")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                    Text("还没有记录。收到短信后回到这里点「刷新」；如果一直是空的，说明自动化根本没调用「转发短信到 Bark」这个动作。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(logs.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().opacity(0.4) }
                        logRow(entry)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    logs = RunLog.load()
                    store.toast = "已刷新"
                } label: {
                    chip("刷新", "arrow.clockwise")
                }
                .buttonStyle(.plain)

                CopyChip(text: logsText, label: "复制全部", note: "运行记录已复制")

                if !logs.isEmpty {
                    Button(role: .destructive) {
                        RunLog.clear()
                        logs = []
                    } label: {
                        Text("清空")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.red.opacity(0.10))
                            .foregroundStyle(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chip(_ label: String, _ symbol: String) -> some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }

    private func logRow(_ entry: RunLogEntry) -> some View {
        let tint: Color = entry.outcome.isBlocked ? .orange : (entry.outcome.isBad ? .red : .green)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: entry.outcome.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(entry.outcome.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(Self.logTime.string(from: entry.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Text(entry.content.isEmpty ? "内容为空" : "\(entry.content.count) 字")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(entry.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.content.isEmpty {
                Text(snippet(entry))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func snippet(_ entry: RunLogEntry) -> String {
        let sender = entry.sender.isEmpty ? "未知发件人" : entry.sender
        return "\(sender)：\(entry.content)"
    }

    private var logsText: String {
        logs.map { entry in
            "[\(Self.logTime.string(from: entry.date))] \(entry.outcome.title) · \(entry.detail)\n\(snippet(entry))"
        }.joined(separator: "\n\n")
    }

    private static let logTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()
}
