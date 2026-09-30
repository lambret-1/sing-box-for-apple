//
//  策略组内容区.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  策略组内容区：展示 selector / urltest / fallback / loadbalance 策略组
//  每组可展开显示节点选择
//  TODO: 第六阶段对接官方 CommandClient 数据
//

import SwiftUI

// MARK: - 占位数据模型

/// 占位策略组节点行
private struct 占位策略节点: Identifiable {
    let id = UUID()
    /// 节点名称
    let 名称: String
    /// 延迟毫秒，nil 表示未测
    let 延迟毫秒: Int?
}

/// 占位策略组
private struct 占位策略组: Identifiable {
    let id = UUID()
    /// 组名称
    let 名称: String
    /// 组类型：selector / urltest / fallback / loadbalance
    let 类型: String
    /// 当前选中节点名
    let 当前选中: String
    /// 组内节点列表
    var 节点列表: [占位策略节点]
    /// 是否展开
    var 是否展开: Bool
}

// MARK: - 策略组内容区视图

/// 策略组内容区视图
struct 策略组内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 占位策略组列表
    // TODO: 第六阶段对接官方 CommandClient 数据
    @State private var 策略组列表: [占位策略组] = [
        占位策略组(
            名称: "代理选择",
            类型: "selector",
            当前选中: "香港 01",
            节点列表: [
                占位策略节点(名称: "香港 01", 延迟毫秒: 42),
                占位策略节点(名称: "香港 02", 延迟毫秒: 58),
                占位策略节点(名称: "东京 01", 延迟毫秒: 86),
                占位策略节点(名称: "洛杉矶 01", 延迟毫秒: 180),
                占位策略节点(名称: "direct", 延迟毫秒: 12)
            ],
            是否展开: true
        ),
        占位策略组(
            名称: "自动测速",
            类型: "urltest",
            当前选中: "香港 01",
            节点列表: [
                占位策略节点(名称: "香港 01", 延迟毫秒: 42),
                占位策略节点(名称: "香港 02", 延迟毫秒: 58),
                占位策略节点(名称: "东京 01", 延迟毫秒: 86),
                占位策略节点(名称: "东京 02", 延迟毫秒: 95)
            ],
            是否展开: false
        ),
        占位策略组(
            名称: "故障转移",
            类型: "fallback",
            当前选中: "香港 01",
            节点列表: [
                占位策略节点(名称: "香港 01", 延迟毫秒: 42),
                占位策略节点(名称: "洛杉矶 01", 延迟毫秒: nil)
            ],
            是否展开: false
        )
    ]

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // VPN 未连接提示骨架
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
                .padding(.horizontal, 间距常量.标准)
                .padding(.top, 8)
            }

            // 策略组列表
            if 策略组列表.isEmpty {
                EmptyStateView(
                    图标: "point.3.connected.trianglepath.dotted",
                    标题: "暂无策略组",
                    说明: "连接 VPN 后自动加载策略组数据"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 间距常量.中等) {
                        ForEach($策略组列表) { $组 in
                            策略组卡片(组: $组)
                        }
                    }
                    .padding(.horizontal, 间距常量.标准)
                    .padding(.bottom, 间距常量.标准)
                }
            }
        }
    }
}

// MARK: - 策略组卡片

/// 单个策略组卡片
private struct 策略组卡片: View {
    @Binding var 组: 占位策略组

    /// 类型中文标题
    private var 类型标题: String {
        switch 组.类型 {
        case "selector": return "手动选择"
        case "urltest": return "自动测速"
        case "fallback": return "故障转移"
        case "loadbalance": return "负载均衡"
        default: return 组.类型
        }
    }

    /// 类型标签颜色
    private var 类型颜色: Color {
        switch 组.类型 {
        case "selector": return Color(red: 0.24, green: 0.77, blue: 0.82)
        case "urltest": return Color(red: 0.98, green: 0.72, blue: 0.20)
        case "fallback": return .警告色
        case "loadbalance": return Color(red: 0.56, green: 0.38, blue: 0.95)
        default: return .次要文字
        }
    }

    /// 是否可手动切换
    private var 可手动切换: Bool {
        组.类型 == "selector"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            Button {
                withAnimation(.easeInOut(duration: 动画常量.标准)) {
                    组.是否展开.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // 组名 + 类型标签
                        HStack(spacing: 8) {
                            Text(组.名称)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(类型标题)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(类型颜色)
                                .cornerRadius(圆角常量.小)
                        }

                        // 当前选中节点
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.成功色)
                                .font(.system(size: 14))
                            Text(组.当前选中)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // 右侧：节点数 + 展开箭头
                    VStack(alignment: .trailing, spacing: 6) {
                        // 组内测速按钮骨架
                        Button {
                            // TODO: 第六阶段对接组内批量测速
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11))
                                Text("测速")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.98, green: 0.72, blue: 0.20))
                            .cornerRadius(圆角常量.小)
                        }
                        .buttonStyle(PlainButtonStyle())

                        HStack(spacing: 4) {
                            Text("\(组.节点列表.count)节点")
                                .font(.system(size: 12))
                                .foregroundColor(.次要文字)
                            Image(systemName: 组.是否展开 ? "chevron.up" : "chevron.down")
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
            if 组.是否展开 {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(组.节点列表) { 节点 in
                        策略节点行(
                            节点: 节点,
                            选中: 组.当前选中 == 节点.名称,
                            可手动切换: 可手动切换
                        )
                    }
                }
                .padding(.bottom, 8)
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
    let 节点: 占位策略节点
    /// 是否当前选中
    let 选中: Bool
    /// 是否可手动切换
    let 可手动切换: Bool

    /// 延迟颜色
    private var 延迟颜色: Color {
        guard let 延迟 = 节点.延迟毫秒 else { return .次要文字 }
        if 延迟 < 100 { return .成功色 }
        if 延迟 < 300 { return .警告色 }
        return .危险色
    }

    var body: some View {
        Button {
            // TODO: 第六阶段对接组内节点切换
        } label: {
            HStack(spacing: 12) {
                // 选中指示器
                Image(systemName: 选中 ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(选中 ? .成功色 : .次要文字.opacity(0.4))
                    .font(.system(size: 18))

                // 节点名称
                Text(节点.名称)
                    .font(.system(size: 14))
                    .foregroundColor(选中 ? .primary : .次要文字)
                    .lineLimit(1)

                Spacer()

                // 延迟
                if let 延迟 = 节点.延迟毫秒 {
                    Text("\(延迟)ms")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(延迟颜色)
                } else {
                    Text("未测")
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                }

                // 测速按钮骨架
                Button {
                    // TODO: 第六阶段对接单节点测速
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                        .frame(width: 28, height: 28)
                        .background(Color.次要文字.opacity(0.1))
                        .cornerRadius(圆角常量.小)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(选中 ? Color.成功色.opacity(0.08) : Color.clear)
        .opacity(可手动切换 ? 1.0 : 0.8)
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
