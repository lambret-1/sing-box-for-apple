//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  第六阶段B - 对接官方 CommandClient 真实数据
//  规则与日志内容区：顶部日志级别筛选器 + 日志列表（通过 @ObservedObject 实时刷新）
//

import SwiftUI
import Libbox
import Library

// MARK: - 日志级别筛选选项

/// 日志级别筛选（对应官方 LogLevel.rawValue：error=2/warn=3/info=4/debug=5/trace=6）
/// nil 表示"全部"
private struct 日志筛选选项: Identifiable, Hashable {
    /// 官方日志级别（nil 表示全部）
    let 级别: LogLevel?
    /// 中文显示名
    let 显示名: String
    /// 颜色
    let 颜色: Color

    var id: Int { 级别?.rawValue ?? 0 }

    /// 全部选项
    static let 全部 = 日志筛选选项(级别: nil, 显示名: "全部", 颜色: .主题色)

    /// 预设选项列表（按从严到宽排列）
    static let 预设: [日志筛选选项] = [
        .全部,
        日志筛选选项(级别: .error, 显示名: "错误", 颜色: .危险色),
        日志筛选选项(级别: .warn, 显示名: "警告", 颜色: .警告色),
        日志筛选选项(级别: .info, 显示名: "信息", 颜色: .主题色),
        日志筛选选项(级别: .debug, 显示名: "调试", 颜色: .次要文字),
        日志筛选选项(级别: .trace, 显示名: "追踪", 颜色: Color.secondary.opacity(0.6))
    ]

    /// 根据 Int 级别值解析颜色
    static func 颜色(level: Int) -> Color {
        guard let lvl = LogLevel(rawValue: level) else { return .次要文字 }
        switch lvl {
        case .error: return .危险色
        case .warn: return .警告色
        case .info: return .主题色
        case .debug: return .次要文字
        case .trace: return Color.secondary.opacity(0.6)
        }
    }

    /// 根据 Int 级别值解析名称
    static func 名称(level: Int) -> String {
        LogLevel(rawValue: level)?.name ?? "未知"
    }
}

// MARK: - 规则与日志内容区（入口视图）

/// 规则与日志内容区入口视图：获取 CommandClient 并传递给子视图
struct 规则与日志内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 当前选中的日志级别筛选（nil 表示全部）
    @State private var 选中级别: LogLevel?

    var body: some View {
        if let 客户端 = 状态.命令客户端 {
            规则与日志内容视图(命令客户端: 客户端, 选中级别: $选中级别)
        } else {
            VStack {
                ProgressView("正在初始化…")
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
            .padding(.horizontal, 间距常量.标准)
        }
    }
}

// MARK: - 规则与日志内容视图（观察 CommandClient）

/// 规则与日志内容视图：通过 @ObservedObject 观察 CommandClient 的 @Published logBuffer，实时刷新
private struct 规则与日志内容视图: View {
    /// 命令客户端（@Published logBuffer / initialLogsReceived 变化时自动刷新）
    @ObservedObject var 命令客户端: CommandClient

    /// 当前选中的日志级别筛选（从入口视图绑定）
    @Binding var 选中级别: LogLevel?

    /// ScrollViewReader 滚动锚点
    private let 滚动锚点 = UUID()

    /// 原始日志条目（官方数据）
    private var 原始日志: [LogEntry] {
        命令客户端.logBuffer.entries
    }

    /// 是否已收到首批日志（区分"加载中"与"暂无日志"）
    private var 已收到首批日志: Bool {
        命令客户端.initialLogsReceived
    }

    /// 过滤后的日志（官方 entries 为新日志在后，反转后新日志在上）
    private var 过滤后日志: [LogEntry] {
        let 列表 = 原始日志.reversed()
        guard let 选中级别 else { return Array(列表) }
        return 列表.filter { $0.level == 选中级别.rawValue }
    }

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 顶部日志级别筛选器 + 清除按钮
            顶部工具栏

            // 日志列表
            if !已收到首批日志 {
                ProgressView("正在加载日志…")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if 过滤后日志.isEmpty {
                EmptyStateView(
                    图标: "doc.text.magnifyingglass",
                    标题: "暂无日志",
                    说明: 选中级别 == nil ? "启动 VPN 后将显示运行日志" : "当前级别下暂无日志"
                )
            } else {
                ScrollViewReader { 代理 in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(过滤后日志) { 日志 in
                                日志行(日志: 日志)
                                if 日志.id != 过滤后日志.last?.id {
                                    Divider()
                                        .padding(.leading, 15)
                                }
                            }
                            // 底部锚点，用于自动滚动到最新
                            Color.clear
                                .frame(height: 1)
                                .id(滚动锚点)
                        }
                        .background(Color.卡片背景)
                        .cornerRadius(圆角常量.标准)
                    }
                    .onChange(of: 过滤后日志.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            代理.scrollTo(滚动锚点, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        代理.scrollTo(滚动锚点, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 顶部工具栏（级别筛选器 + 清除按钮）

    /// 顶部横向滚动的日志级别筛选胶囊 + 右侧清除按钮
    private var 顶部工具栏: some View {
        HStack(spacing: 间距常量.紧凑) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 间距常量.紧凑) {
                    ForEach(日志筛选选项.预设) { 选项 in
                        级别胶囊(
                            标题: 选项.显示名,
                            颜色: 选项.颜色,
                            选中: 选中级别 == 选项.级别
                        ) {
                            withAnimation(.easeInOut(duration: 动画常量.快速)) {
                                选中级别 = 选项.级别
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // 清除日志按钮
            Button {
                命令客户端.clearLogs()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.次要文字)
                    .padding(8)
                    .background(Color.卡片背景)
                    .cornerRadius(圆角常量.标准)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    /// 单个级别筛选胶囊
    private func 级别胶囊(标题: String, 颜色: Color, 选中: Bool, 动作: @escaping () -> Void) -> some View {
        Button(action: 动作) {
            Text(标题)
                .font(.system(size: 12, weight: 选中 ? .semibold : .medium))
                .foregroundColor(选中 ? .white : 颜色)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(选中 ? 颜色 : 颜色.opacity(0.12))
                .cornerRadius(圆角常量.标准)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 日志行

/// 单条日志行
private struct 日志行: View {
    /// 日志数据（官方 LogEntry）
    let 日志: LogEntry

    /// 级别颜色
    private var 级别颜色: Color { 日志筛选选项.颜色(level: 日志.level) }

    /// 级别名称
    private var 级别名称: String { 日志筛选选项.名称(level: 日志.level) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 级别圆点
            Circle()
                .fill(级别颜色)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                // 级别标签
                HStack(spacing: 6) {
                    Text(级别名称)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(级别颜色)
                        .cornerRadius(圆角常量.小)
                }

                // 日志消息（等宽字体，可换行）
                Text(日志.message)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        规则与日志内容区()
            .environmentObject(新UI状态())
    }
    .background(Color.页面背景)
}
