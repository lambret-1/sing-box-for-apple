//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  规则与日志内容区：顶部日志级别筛选器 + 日志列表（级别标签 + 消息）
//  TODO: 第六阶段对接官方 CommandClient 数据
//

import SwiftUI

// MARK: - 日志级别枚举

/// 日志级别
enum 日志级别: String, CaseIterable, Identifiable {
    case 追踪 = "trace"
    case 调试 = "debug"
    case 信息 = "info"
    case 警告 = "warn"
    case 错误 = "error"
    case 致命 = "fatal"

    var id: String { rawValue }

    /// 中文显示名
    var 显示名: String {
        switch self {
        case .追踪: return "追踪"
        case .调试: return "调试"
        case .信息: return "信息"
        case .警告: return "警告"
        case .错误: return "错误"
        case .致命: return "致命"
        }
    }

    /// 级别颜色
    var 颜色: Color {
        switch self {
        case .致命: return Color(red: 0.56, green: 0.38, blue: 0.95)
        case .错误: return .危险色
        case .警告: return .警告色
        case .信息: return .主题色
        case .调试, .追踪: return .次要文字
        }
    }
}

// MARK: - 占位日志条目

/// 占位日志条目
private struct 占位日志项: Identifiable {
    let id = UUID()
    /// 日志级别
    let 级别: 日志级别
    /// 模块名
    let 模块: String
    /// 日志时间
    let 时间: Date
    /// 日志消息
    let 消息: String
}

// MARK: - 规则与日志内容区视图

/// 规则与日志内容区视图
struct 规则与日志内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 当前选中的日志级别筛选（nil 表示全部）
    @State private var 选中级别: 日志级别?

    /// 占位日志列表
    // TODO: 第六阶段对接官方 CommandClient 数据
    @State private var 日志列表: [占位日志项] = [
        占位日志项(级别: .信息, 模块: "sing-box", 时间: Date().addingTimeInterval(-5),
                   消息: "sing-box started, sing-box version 1.10.0"),
        占位日志项(级别: .信息, 模块: " inbound", 时间: Date().addingTimeInterval(-8),
                   消息: "[inbound] socks inbound listening at 127.0.0.1:1080"),
        占位日志项(级别: .信息, 模块: "inbound", 时间: Date().addingTimeInterval(-9),
                   消息: "[inbound] mixed inbound listening at 127.0.0.1:1081"),
        占位日志项(级别: .调试, 模块: "outbound", 时间: Date().addingTimeInterval(-15),
                   消息: "[outbound] dialed to 香港 01 (hk01.example.com:443)"),
        占位日志项(级别: .警告, 模块: "router", 时间: Date().addingTimeInterval(-32),
                   消息: "[router] rule [广告拦截] matched domain doubleclick.net, action: reject"),
        占位日志项(级别: .信息, 模块: "router", 时间: Date().addingTimeInterval(-48),
                   消息: "[router] rule [苹果服务] matched www.apple.com, outbound: direct"),
        占位日志项(级别: .错误, 模块: "outbound", 时间: Date().addingTimeInterval(-60),
                   消息: "[outbound] connection to 洛杉矶 01 timeout: dial tcp i/o timeout"),
        占位日志项(级别: .调试, 模块: "dns", 时间: Date().addingTimeInterval(-75),
                   消息: "[dns] query www.apple.com -> 17.253.144.10 (h2)"),
        占位日志项(级别: .信息, 模块: "clash-api", 时间: Date().addingTimeInterval(-90),
                   消息: "[clash-api] listening at 127.0.0.1:9090"),
        占位日志项(级别: .致命, 模块: "core", 时间: Date().addingTimeInterval(-120),
                   消息: "[core] configuration reload failed: invalid field \"mixed-port\"")
    ]

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式
    }()

    /// 过滤后的日志
    private var 过滤后日志: [占位日志项] {
        guard let 选中级别 else { return 日志列表 }
        return 日志列表.filter { $0.级别 == 选中级别 }
    }

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 顶部日志级别筛选器
            级别筛选器

            // 日志列表
            if 过滤后日志.isEmpty {
                EmptyStateView(
                    图标: "doc.text.magnifyingglass",
                    标题: "暂无日志",
                    说明: "启动 VPN 后将显示运行日志"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(过滤后日志) { 日志 in
                            日志行(日志: 日志, 时间格式: 时间格式)
                            if 日志.id != 过滤后日志.last?.id {
                                Divider()
                                    .padding(.leading, 15)
                            }
                        }
                    }
                    .background(Color.卡片背景)
                    .cornerRadius(圆角常量.标准)
                }
            }
        }
        .padding(.horizontal, 间距常量.标准)
    }

    // MARK: - 级别筛选器

    /// 顶部横向滚动的日志级别筛选胶囊
    private var 级别筛选器: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 间距常量.紧凑) {
                // "全部" 选项
                级别胶囊(标题: "全部", 颜色: .主题色, 选中: 选中级别 == nil) {
                    选中级别 = nil
                }

                ForEach(日志级别.allCases) { 级别 in
                    级别胶囊(
                        标题: 级别.显示名,
                        颜色: 级别.颜色,
                        选中: 选中级别 == 级别
                    ) {
                        withAnimation(.easeInOut(duration: 动画常量.快速)) {
                            选中级别 = 级别
                        }
                    }
                }
            }
            .padding(.vertical, 4)
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
    /// 日志数据
    let 日志: 占位日志项
    /// 外部传入的时间格式化器
    let 时间格式: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 级别圆点
            Circle()
                .fill(日志.级别.颜色)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                // 模块 + 时间
                HStack(spacing: 8) {
                    Text(日志.模块)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.次要文字)
                    Text(时间格式.string(from: 日志.时间))
                        .font(.system(size: 11))
                        .foregroundColor(.次要文字)
                }

                // 级别标签 + 消息
                HStack(alignment: .top, spacing: 6) {
                    Text(日志.级别.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(日志.级别.颜色)
                        .cornerRadius(圆角常量.小)

                    Text(日志.消息)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
