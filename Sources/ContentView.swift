import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var tab: Int = LaunchOptions.initialTab

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("概览", systemImage: "house.fill") }
                .tag(0)
            ConfigView()
                .tabItem { Label("推送", systemImage: "paperplane.fill") }
                .tag(1)
            RulesView()
                .tabItem { Label("拦截", systemImage: "hand.raised.fill") }
                .tag(2)
            GuideView()
                .tabItem { Label("指引", systemImage: "book.fill") }
                .tag(3)
        }
        .environmentObject(store)
        .modifier(LiquidGlassTabBar())
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .padding(.bottom, 62)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: store.toast)
        .onChange(of: store.toast) { value in
            guard let value else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_100_000_000)
                if store.toast == value { store.toast = nil }
            }
        }
    }
}

/// 调试用的启动参数：`-tab 2` 直接打开第 3 个页签，方便截图验证。
enum LaunchOptions {    static var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count,
           let value = Int(args[idx + 1]) {
            return min(max(value, 0), 3)
        }
        return 0
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - 液态玻璃标签栏

/// iOS 26/27 的系统 TabView 自带液态玻璃标签栏：胶囊浮在内容上方、随滚动折射背景。
/// 前提是必须用 iOS 26 及以上的 SDK 编译（老 SDK 编出来的还是旧版平铺样式）。
/// 这里再补一条：向下滚动时标签栏自动收成小胶囊，向上滚回来恢复，和系统 App 一致。
private struct LiquidGlassTabBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}
