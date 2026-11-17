# SmsBark · iOS 短信转发到 Bark

一台 iPhone 收到短信 → 快捷指令调起本 App 的动作 → 自动判定拦截关键词 → 推送到 Bark → 另一台 iPhone 立刻响。

**直接下载 IPA**：https://github.com/JLzsonit/SmsBark/releases/latest
（当前最新 **v1.4.3 (9)**，未签名，需自行用 Sideloadly / AltStore 签一次，见下文）

**界面预览**（模拟器实拍，见 `docs/screenshots/`）：概览 / 推送 / 拦截 / 指引 四个页签。

v1.1 起，App 通过 App Intents 向快捷指令提供一个「转发短信到 Bark」动作——装好 App 后在快捷指令里直接能搜到，自动化 4 步搭完，不用再手动拼六步动作。**v1.2 起，拦截页里配的关键词会在动作执行时自动判定**：黑名单命中 / 白名单未命中的短信不发任何请求，加词删词即刻生效，快捷指令里无需加任何判断动作。**v1.2.1 起，「指引」页提供一键创建按钮**：直接深链跳到快捷指令的新建自动化页（触发器和动作因苹果安全限制无法由 App 预填，剩余 4 步照 App 内清单点完即可）。**v1.3 起，拦截页新增「运行记录」**：动作每次执行都会写下收到什么、判定结果、HTTP 结果，用来定位「明明加了关键词却还是收到」——最常见的原因是自动化里「短信内容」没接到变量，导致内容为空、规则判不出来；同时关键词匹配做了全角/半角与空格归一化。**v1.4 起改用 iOS 27 SDK 编译**：底部标签栏直接采用系统的液态玻璃外观（胶囊浮在内容上方、随滚动折射背景、向下滚动自动收成小胶囊），iPhone 上的观感与系统 App 一致；iOS 26 及更早系统会自动回退成旧版样式。

本仓库是这个方案的 **iOS 客户端**：原生 SwiftUI，负责配置、拼推送链接、管理拦截规则、本地试判定和链路自测。用来在 GitHub 的 macOS 机器上直接编译出 IPA，不需要自己有 Mac。

---

## 先说清楚边界

iOS 不允许任何第三方 App 读取短信收件箱，App Store 也不允许上架这类能力。所以：

- **收到短信这件事，只能由系统「快捷指令」的自动化接管**，任何号称能读短信的 iOS App 都不真实；
- 本 App 做的是它旁边所有能干的事：把配置调好、把链接拼对、把规则算准、把请求测通；
- 落在手机上的动作只有一条 GET 请求，没有后台常驻，几乎不耗电。

## 功能

| 页面 | 内容 |
| --- | --- |
| 概览 | 当前配置状态、掩码显示的 Key、一键测试推送、整条链路图解 |
| 推送 | 服务器地址（支持自建 Bark）、Device Key、标题、分组、中断级别、提示音、重复响铃、图标、点击跳转、正文模板、拼好的链接 |
| 拦截 | 黑名单 / 白名单双模式、关键词增删、常用词库、拦截后留痕开关、粘贴短信实时判定拦不拦（规则自动作用于快捷指令动作） |
| 指引 | 4 步搭完的自动化流程（一键动作）、常见坑、FAQ |

配置全部存在本机 `UserDefaults`，不联网、不上传、无统计埋点。

## 自动化怎么建（iOS 27 实测路径）

装好 App 后，快捷指令里就能搜到本 App 提供的「转发短信到 Bark」动作，4 步建完：

1. 快捷指令 → 底部「**自动化**」→ 右上角 ＋ → 选「**通知**」→ 条件「**我收到来自 信息**」（发件人留空＝所有短信都转发）
2. 「添加操作」→ 搜「短信转发」→ 选「**转发短信到 Bark**」
3. 接变量（唯一容易点错的一步）：
   - 点「发件人」框 → 面板里点「快捷指令输入」→ 轻点「输入快捷指令的信息」
   - 类型选「**通知**」→「获取」里选「**发件人**」
   - 「短信内容」框重复同样的路径，最后「获取」里选「**正文**」
4. 关掉「运行前询问」→ 右上角「完成」

关键词拦截在这一步自动生效，快捷指令里不需要加任何判断动作。注意：参数框里永远只用「选择变量」，不要用键盘打字，打进去的是固定文字。


## 怎么拿到 IPA

没有 Mac 也能出包，用 GitHub 的 macOS 机器编译。本仓库已经在 GitHub 上跑通过，产物挂在 [Releases](https://github.com/JLzsonit/SmsBark/releases/latest)：

```
https://github.com/JLzsonit/SmsBark/releases/download/v1.4.3/SmsBark-unsigned.ipa
```

自己重新构建：

1. 改完代码 `git push`（或去 **Actions → Build IPA → Run workflow** 手动触发）；
2. 工作流用 `xcode-27`（Xcode 27.1 / iOS 27.1 SDK）编译，`macos-26`（Xcode 26.6 / iOS 26 SDK）作为备份腿并行排队，哪个先拿到机器就用哪个；Release 只从 iOS 27 那条腿发布；
3. 跑完后在该次运行页面底部 **Artifacts** 下载 `SmsBark-ipa-*.zip`，解压得到 `SmsBark-unsigned.ipa`；
4. 打 tag（`git tag v1.4.4 && git push origin v1.4.4`）会自动把 IPA 挂到 Release；发布说明取自 `docs/release-notes/<tag>.md`，没有这个文件时退回「完整变更」链接。

### 安装到 iPhone

产物是**未签名 IPA**，不能双击装，需要自己签一下：

- **Sideloadly / AltStore**（Windows 可用，推荐）：填 Apple ID 免费签名，手机信任开发者证书即可用，有效期 7 天，到期重签；
- **TrollStore**：支持的系统上可永久安装，无需签名；
- 有付费开发者账号的话，也可以用 Xcode / Apple Configurator 自己签。

当前产物信息：

| 项 | 值 |
| --- | --- |
| 包名 | `cn.zsonit.smsbark` |
| 版本 | 1.4.3 (9) |
| 最低系统 | iOS 16.0 |
| 架构 | arm64（真机） |
| 编译 SDK | iOS 27.1 |
| 安装方式 | Sideloadly / AltStore / TrollStore 签名后安装 |

## 本地构建（有 Mac 时）

```bash
brew install xcodegen
xcodegen generate
open SmsBark.xcodeproj
```

工程文件 `SmsBark.xcodeproj` 由 `project.yml` 生成，不纳入版本管理，改完配置重新 `xcodegen generate` 即可。

## 目录结构

```
SmsBark/
├── project.yml                 # XcodeGen 工程定义（含 Info.plist 属性）
├── Sources/
│   ├── SmsBarkApp.swift        # 入口
│   ├── ContentView.swift       # 四个标签页
│   ├── Models.swift            # 配置模型、URL 拼接、规则判定、正则生成
│   ├── Store.swift             # 状态与本地持久化、测试推送
│   ├── Components.swift        # 卡片、代码块、复制按钮等
│   ├── HomeView.swift
│   ├── ConfigView.swift
│   ├── RulesView.swift
│   └── GuideView.swift
├── Resources/Assets.xcassets   # App 图标与主题色
├── dist/                       # 本地留存的构建产物（IPA + 校验值，不入库）
├── docs/index.html             # 同方案的可视化配置器（网页版，可开 GitHub Pages）
├── docs/release-notes/          # 每个 tag 的发布说明，push 后自动覆盖 Release 说明
└── .github/workflows/          # build-ipa.yml 编译打包 / release-notes.yml 更新说明 / screenshots.yml 截图
```

## 网页版

`docs/index.html` 是同一套逻辑的可视化配置器，单文件、离线可用，适合在电脑上边填边看效果。开启方式：仓库 **Settings → Pages → Source 选 `main` / `/docs`**，之后用 Pages 域名访问即可。

## 相关项目

同目录下的 `../SmsForwarder` 是安卓侧的短信转发与拦截 App（基于 SmsForwarder 二次开发）。两边解决的是同一个问题，实现路径完全不同：安卓能直接读短信，iOS 只能借快捷指令。

## 隐私

- 不收集任何数据，没有服务端；
- Device Key 与规则只写在本机；
- 唯一的网络请求是你主动触发的 Bark 推送。

## License

MIT

