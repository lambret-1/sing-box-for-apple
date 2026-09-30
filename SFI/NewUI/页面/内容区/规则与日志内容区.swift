//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  重构：使用官方 LogDataModel 获取数据，自定义 SwiftUI 原生列表显示
//  避免官方 LogView 内嵌 UIViewRepresentable 在 ScrollView 中高度异常
//  移除空状态自动 connect 逻辑，避免干扰 VPN 连接
//

import SwiftUI
import ApplicationLibrary
import Library
import Libbox

// MARK: - 日志级别筛选选项

/// 日志级别筛选（nil 表示全部）
private struct 日志筛选选项: Identifiable, Hashable {
    let 级别: LogLevel?
    let 显示名: String
    let 颜色: Color

    var id: Int { 级别?.rawValue ?? 0 }

    static let 全部 = 日志筛选选项(级别: nil, 显示名: "全部", 颜色: .主题色)
    static let 预设: [日志筛选选项] = [
        .全部,
        日志筛选选项(级别: .error, 显示名: "错误", 颜色: .危险色),
        日志筛选选项(级别: .warn, 显示名: "警告", 颜色: .警告色),
        日志筛选选项(级别: .info, 显示名: "信息", 颜色: .主题色),
        日志筛选选项(级别: .debug, 显示名: "调试", 颜色: .次要文字),
        日志筛选选项(级别: .trace, 显示名: "追踪", 颜色: Color.secondary.opacity(0.6))
    ]
}

// MARK: - 规则与日志内容区入口

/// 规则与日志内容区入口视图
struct 规则与日志内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态
    /// 官方扩展环境
    @EnvironmentObject private var 环境: ExtensionEnvironments

    var body: some View {
        VStack(spacing: 0) {
            // VPN 未连接提示
            if !状态.是否已连接 {
                HStack(spacing: 间距常量.紧凑) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.警告色)
                        .font(.system(size: 14))
                    Text("VPN 未连接，日志可能未更新")
                        .font(.system(size: 13))
                        .foregroundColor(.警告色)
                    Spacer()
                }
                .padding(.horizontal, 间距常量.标准)
                .padding(.vertical, 8)
            }

            // 日志内容视图（使用官方数据模型，自定义UI）
            if let 客户端 = 状态.命令客户端 {
                日志内容视图(命令客户端: 客户端)
            } else {
                VStack {
                    ProgressView("正在初始化…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
        .background(Color.页面背景)
    }
}

// MARK: - 日志内容视图（使用官方 LogDataModel）

/// 日志内容视图：使用官方 LogDataModel 获取数据，SwiftUI 原生列表显示
private struct 日志内容视图: View {
    /// 命令客户端
    let 命令客户端: CommandClient

    /// 官方日志视图模型
    @StateObject private var 视图模型: LogViewModel
    /// 官方日志数据模型
    @StateObject private var 数据模型: LogDataModel

    /// 当前选中的日志级别筛选
    @State private var 选中级别: LogLevel? = nil
    /// 搜索关键词
    @State private var 搜索关键词 = ""
    /// 是否暂停自动滚动
    @State private var 暂停滚动 = false
    /// ScrollView 滚动锚点
    private let 滚动锚点 = "日志底部锚点"

    init(命令客户端: CommandClient) {
        self.命令客户端 = 命令客户端
        let vm = LogViewModel(commandClient: 命令客户端)
        _视图模型 = StateObject(wrappedValue: vm)
        _数据模型 = StateObject(wrappedValue: LogDataModel(commandClient: 命令客户端, viewModel: vm))
    }

    /// 过滤后的日志（官方 visibleLogs 已处理级别筛选，这里再加搜索过滤）
    private var 过滤后日志: [LogEntry] {
        let 列表 = 数据模型.visibleLogs
        guard !搜索关键词.isEmpty else { return 列表 }
        let 关键词 = 搜索关键词.lowercased()
        return 列表.filter { $0.message.lowercased().contains(关键词) }
    }

    var body: some View {
        VStack(spacing: 间距常量.紧凑) {
            // 顶部工具栏：级别筛选 + 搜索 + 暂停 + 清除
            顶部工具栏

            // 日志列表
            if !数据模型.initialLogsReceived {
                ProgressView("正在加载日志…")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if 过滤后日志.isEmpty {
                EmptyStateView(
                    图标: "doc.text.magnifyingglass",
                    标题: 搜索关键词.isEmpty ? "暂无日志" : "未找到匹配日志",
                    说明: 搜索关键词.isEmpty ? "启动 VPN 后将显示运行日志" : "尝试更换搜索关键词"
                )
            } else {
                ScrollViewReader { 代理 in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(过滤后日志) { 日志 in
                                日志行(日志: 日志)
                            }
                            // 底部锚点
                            Color.clear
                                .frame(height: 1)
                                .id(滚动锚点)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(Color.卡片背景)
                    .cornerRadius(圆角常量.标准)
                    .onChange(of: 过滤后日志.count) { _ in
                        if !暂停滚动 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                代理.scrollTo(滚动锚点, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        代理.scrollTo(滚动锚点, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.bottom, 间距常量.标准)
    }

    // MARK: - 顶部工具栏

    private var 顶部工具栏: some View {
        VStack(spacing: 间距常量.紧凑) {
            // 第一行：级别筛选标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(日志筛选选项.预设) { 选项 in
                        Button {
                            选中级别 = 选项.级别
                            视图模型.selectedLogLevel = 选项.级别?.rawValue
                        } label: {
                            Text(选项.显示名)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(选中级别 == 选项.级别 ? .white : 选项.颜色)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 圆角常量.小)
                                        .fill(选中级别 == 选项.级别 ? 选项.颜色 : Color.页面背景)
                                )
                        }
                    }
                    Spacer()
                }
            }

            // 第二行：搜索框 + 暂停 + 清除
            HStack(spacing: 间距常量.紧凑) {
                // 搜索框
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                    TextField("搜索日志", text: $搜索关键词)
                        .font(.system(size: 13))
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                    if !搜索关键词.isEmpty {
                        Button {
                            搜索关键词 = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.次要文字)
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.页面背景)
                .cornerRadius(圆角常量.小)

                // 暂停/继续按钮
                Button {
                    暂停滚动.toggle()
                    视图模型.isPaused = 暂停滚动
                } label: {
                    Image(systemName: 暂停滚动 ? "play.circle" : "pause.circle")
                        .font(.system(size: 20))
                        .foregroundColor(暂停滚动 ? .成功色 : .次要文字)
                }

                // 清除按钮
                Button {
                    数据模型.clearLogs()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(.危险色)
                }
            }
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(圆角常量.标准)
    }
}

// MARK: - 日志行

/// 单个日志条目行
private struct 日志行: View {
    let 日志: LogEntry

    /// 日志级别颜色
    private var 级别颜色: Color {
        switch 日志.level {
        case 2: return .危险色    // error
        case 3: return .警告色    // warn
        case 4: return .主题色    // info
        case 5: return .次要文字  // debug
        case 6: return Color.secondary.opacity(0.6) // trace
        default: return .次要文字
        }
    }

    /// 日志级别名称
    private var 级别名称: String {
        switch 日志.level {
        case 2: return "错误"
        case 3: return "警告"
        case 4: return "信息"
        case 5: return "调试"
        case 6: return "追踪"
        default: return "未知"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 级别标签
            Text(级别名称)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(级别颜色)
                .cornerRadius(3)
                .frame(width: 36, alignment: .center)

            // 日志内容
            Text(日志.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 预览

#Preview {
    规则与日志内容区()
        .environmentObject(新UI状态())
        .environmentObject(ExtensionEnvironments())
        .background(Color.页面背景)
}
