//
//  策略组内容区.swift
//  sing-box-for-apple 新UI
//
//  第六阶段 - 对接官方 CommandClient 真实数据
//  策略组内容区：展示 selector / urltest / fallback / loadbalance 策略组
//  每组可展开显示节点选择，支持节点切换与组内批量测速
//

import SwiftUI
import Library

// MARK: - 策略组内容区视图

/// 策略组内容区视图
struct 策略组内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // VPN 未连接提示
            if !状态.是否已连接 {
                HStack(spacing: 间距常量.紧凑) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.警告色)
                        .font(.system(size: 14))
                    Text("VPN 未连接，策略组数据可能未更新")
                        .font(.system(size: 13))
                        .foregroundColor(.警告色)
                    Spacer()
                }
                .padding(.top, 8)
            }

            // 根据命令客户端是否可用切换展示
            if let 客户端 = 状态.命令客户端 {
                策略组列表视图(命令客户端: 客户端)
            } else {
                // 命令客户端尚未就绪
                ProgressView("正在连接服务…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - 策略组列表视图（观察 CommandClient.groups）

/// 策略组列表视图：通过 @ObservedObject 观察 CommandClient 的 @Published groups
private struct 策略组列表视图: View {
    /// 命令客户端（@Published groups 变化时自动刷新）
    @ObservedObject var 命令客户端: CommandClient

    /// 全局新UI状态（用于切换节点 / 测速操作）
    @EnvironmentObject private var 状态: 新UI状态

    /// 组展开/收起状态（按组标签本地管理，避免被服务端推送覆盖）
    @State private var 展开状态: [String: Bool] = [:]

    /// 正在测速的组标签集合
    @State private var 测速中组: Set<String> = []

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            if let 组列表 = 命令客户端.groups {
                if 组列表.isEmpty {
                    EmptyStateView(
                        图标: "point.3.connected.trianglepath.dotted",
                        标题: "暂无策略组",
                        说明: "连接 VPN 后自动加载策略组数据"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 间距常量.中等) {
                            ForEach(组列表, id: \.tag) { 组 in
                                策略组卡片(
                                    组: 组,
                                    是否展开: 展开状态[组.tag] ?? false,
                                    测速中: 测速中组.contains(组.tag),
                                    展开回调: { 切换展开(组标签: 组.tag) },
                                    切换节点回调: { 节点标签 in
                                        Task { await 状态.切换节点(组标签: 组.tag, 节点标签: 节点标签) }
                                    },
                                    测速回调: {
                                        await 组内测速(组标签: 组.tag)
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 间距常量.标准)
                    }
                }
            } else {
                // groups 尚未推送（连接建立中）
                ProgressView("正在加载策略组…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 本地操作

    /// 切换组展开/收起
    private func 切换展开(组标签: String) {
        withAnimation(.easeInOut(duration: 动画常量.标准)) {
            展开状态[组标签] = !(展开状态[组标签] ?? false)
        }
    }

    /// 触发组内批量测速
    private func 组内测速(组标签: String) async {
        guard !测速中组.contains(组标签) else { return }
        测速中组.insert(组标签)
        defer { 测速中组.remove(组标签) }
        await 状态.测速(组标签: 组标签)
    }
}

// MARK: - 策略组类型工具

/// 策略组类型中文标签
private func 策略组类型标题(_ 类型: String) -> String {
    switch 类型 {
    case "selector": return "手动选择"
    case "urltest": return "自动测速"
    case "fallback": return "故障转移"
    case "loadbalance": return "负载均衡"
    default: return 类型
    }
}

/// 策略组类型标签颜色
private func 策略组类型颜色(_ 类型: String) -> Color {
    switch 类型 {
    case "selector": return Color(red: 0.24, green: 0.77, blue: 0.82)
    case "urltest": return Color(red: 0.98, green: 0.72, blue: 0.20)
    case "fallback": return .警告色
    case "loadbalance": return Color(red: 0.56, green: 0.38, blue: 0.95)
    default: return .次要文字
    }
}

/// 延迟颜色（按毫秒分级）
private func 延迟颜色(_ 延迟: UInt16) -> Color {
    if 延迟 == 0 { return .次要文字 }
    if 延迟 < 100 { return .成功色 }
    if 延迟 < 300 { return .警告色 }
    return .危险色
}

// MARK: - 策略组卡片

/// 单个策略组卡片
private struct 策略组卡片: View {
    /// 策略组数据
    let 组: OutboundGroup

    /// 是否展开
    let 是否展开: Bool

    /// 组内是否正在测速
    let 测速中: Bool

    /// 展开/收起回调
    let 展开回调: () -> Void

    /// 点击节点切换回调
    let 切换节点回调: (String) -> Void

    /// 组内测速回调
    let 测速回调: () async -> Void

    /// 是否可手动切换（仅 selector 类型）
    private var 可手动切换: Bool {
        组.type == "selector"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            Button(action: 展开回调) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // 组名 + 类型标签
                        HStack(spacing: 8) {
                            Text(组.tag)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(策略组类型标题(组.type))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(策略组类型颜色(组.type))
                                .cornerRadius(圆角常量.小)
                        }

                        // 当前选中节点
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.成功色)
                                .font(.system(size: 14))
                            Text(组.selected)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // 右侧：节点数 + 展开箭头
                    VStack(alignment: .trailing, spacing: 6) {
                        // 组内测速按钮
                        Button {
                            Task { await 测速回调() }
                        } label: {
                            HStack(spacing: 3) {
                                if 测速中 {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11))
                                }
                                Text(测速中 ? "测速中" : "测速")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(测速中 ? Color.次要文字 : Color(red: 0.98, green: 0.72, blue: 0.20))
                            .cornerRadius(圆角常量.小)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(测速中)

                        HStack(spacing: 4) {
                            Text("\(组.items.count)节点")
                                .font(.system(size: 12))
                                .foregroundColor(.次要文字)
                            Image(systemName: 是否展开 ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.次要文字)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // 展开内容：节点列表
            if 是否展开 {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(组.items, id: \.tag) { 节点 in
                        策略节点行(
                            节点: 节点,
                            选中: 组.selected == 节点.tag,
                            可手动切换: 可手动切换,
                            切换回调: { 切换节点回调(节点.tag) }
                        )
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(Color.卡片背景)
        .cornerRadius(圆角常量.标准)
    }
}

// MARK: - 策略节点行

/// 策略组内节点行
private struct 策略节点行: View {
    /// 节点数据
    let 节点: OutboundGroupItem

    /// 是否当前选中
    let 选中: Bool

    /// 是否可手动切换
    let 可手动切换: Bool

    /// 点击切换回调
    let 切换回调: () -> Void

    var body: some View {
        Button {
            guard 可手动切换 else { return }
            切换回调()
        } label: {
            HStack(spacing: 12) {
                // 选中指示器
                Image(systemName: 选中 ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(选中 ? .成功色 : .次要文字.opacity(0.4))
                    .font(.system(size: 18))

                // 节点名称
                Text(节点.tag)
                    .font(.system(size: 14))
                    .foregroundColor(选中 ? .primary : .次要文字)
                    .lineLimit(1)

                Spacer()

                // 延迟
                if 节点.urlTestDelay > 0 {
                    Text("\(节点.urlTestDelay)ms")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(延迟颜色(节点.urlTestDelay))
                } else {
                    Text("未测")
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!可手动切换)
        .background(选中 ? Color.成功色.opacity(0.08) : Color.clear)
        .opacity(可手动切换 ? 1.0 : 0.6)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        策略组内容区()
            .environmentObject(新UI状态())
    }
    .background(Color.页面背景)
}
