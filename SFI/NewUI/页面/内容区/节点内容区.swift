//
//  节点内容区.swift
//  sing-box-for-apple 新UI
//
//  第六阶段 - 对接官方 CommandClient 真实数据
//  节点列表内容区：搜索栏 + 分组节点双卡片网格 + 延迟徽章 + 选中状态
//  节点数据来源于 CommandClient.groups（按策略组分组展示）
//

import SwiftUI
import Library

// MARK: - 节点内容区视图

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            if let 客户端 = 状态.命令客户端 {
                节点列表视图(命令客户端: 客户端)
            } else {
                ProgressView("正在连接服务…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - 节点列表视图（观察 CommandClient.groups）

/// 节点列表视图：通过 @ObservedObject 观察 CommandClient 的 @Published groups
private struct 节点列表视图: View {
    /// 命令客户端（@Published groups 变化时自动刷新）
    @ObservedObject var 命令客户端: CommandClient

    /// 全局新UI状态（用于切换节点操作）
    @EnvironmentObject private var 状态: 新UI状态

    /// 搜索关键词
    @State private var 搜索关键词 = ""

    /// 组展开/收起状态（按组标签本地管理）
    @State private var 展开状态: [String: Bool] = [:]

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 间距常量.紧凑),
        GridItem(.flexible(), spacing: 间距常量.紧凑)
    ]

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 搜索栏
            搜索栏

            if let 组列表 = 命令客户端.groups {
                let 过滤后 = 过滤后分组(组列表)
                if 过滤后.isEmpty {
                    EmptyStateView(
                        图标: "server.rack",
                        标题: 搜索关键词.isEmpty ? "暂无节点" : "未找到匹配节点",
                        说明: 搜索关键词.isEmpty ? "连接 VPN 后自动加载节点数据" : "换个关键词试试"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 间距常量.中等) {
                            ForEach(过滤后, id: \.tag) { 组 in
                                分组卡片(
                                    组: 组,
                                    是否展开: 展开状态[组.tag] ?? true,
                                    展开回调: { 切换展开(组标签: 组.tag) },
                                    切换节点回调: { 节点标签 in
                                        Task { await 状态.切换节点(组标签: 组.tag, 节点标签: 节点标签) }
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 间距常量.标准)
                    }
                }
            } else {
                // groups 尚未推送
                ProgressView("正在加载节点…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 搜索栏

    private var 搜索栏: some View {
        HStack(spacing: 间距常量.紧凑) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.次要文字)
            TextField("搜索节点名称", text: $搜索关键词)
                .font(.system(size: 14))
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
            if !搜索关键词.isEmpty {
                Button {
                    搜索关键词 = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.次要文字)
                }
            }
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 10)
        .background(Color.卡片背景)
        .cornerRadius(圆角常量.标准)
    }

    // MARK: - 搜索过滤

    /// 按节点名(tag)过滤，返回过滤后的策略组（保留组内过滤后的节点）
    private func 过滤后分组(_ 组列表: [OutboundGroup]) -> [OutboundGroup] {
        guard !搜索关键词.isEmpty else { return 组列表 }
        let 关键词 = 搜索关键词.lowercased()
        return 组列表.compactMap { 组 in
            let 过滤节点 = 组.items.filter { $0.tag.lowercased().contains(关键词) }
            guard !过滤节点.isEmpty else { return nil }
            var 新组 = 组
            新组.items = 过滤节点
            return 新组
        }
    }

    // MARK: - 本地操作

    /// 切换组展开/收起
    private func 切换展开(组标签: String) {
        withAnimation(.easeInOut(duration: 动画常量.标准)) {
            展开状态[组标签] = !(展开状态[组标签] ?? true)
        }
    }
}

// MARK: - 延迟颜色工具

/// 延迟颜色（按毫秒分级）
private func 节点延迟颜色(_ 延迟: UInt16) -> Color {
    if 延迟 == 0 { return .次要文字 }
    if 延迟 < 100 { return .成功色 }
    if 延迟 < 300 { return .警告色 }
    return .危险色
}

// MARK: - 分组卡片

/// 节点分组卡片（可展开/收起），对应一个策略组
private struct 分组卡片: View {
    /// 策略组数据
    let 组: OutboundGroup

    /// 是否展开
    let 是否展开: Bool

    /// 展开/收起回调
    let 展开回调: () -> Void

    /// 点击节点切换回调
    let 切换节点回调: (String) -> Void

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 间距常量.紧凑),
        GridItem(.flexible(), spacing: 间距常量.紧凑)
    ]

    /// 是否可手动切换（仅 selector 类型）
    private var 可手动切换: Bool {
        组.type == "selector"
    }

    var body: some View {
        VStack(spacing: 间距常量.紧凑) {
            // 分组标题行
            HStack(spacing: 间距常量.紧凑) {
                // 组类型图标
                Image(systemName: 可手动切换 ? "hand.tap" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.主题色)
                    .frame(width: 32, height: 32)

                Text(组.tag)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // 节点数量 + 展开箭头
                HStack(spacing: 6) {
                    Text("\(组.items.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.次要文字)
                    Image(systemName: 是否展开 ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.次要文字)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.卡片背景)
            .cornerRadius(圆角常量.标准)
            .contentShape(Rectangle())
            .onTapGesture {
                展开回调()
            }

            // 展开的节点双卡片网格
            if 是否展开 {
                LazyVGrid(columns: 网格列, spacing: 间距常量.紧凑) {
                    ForEach(组.items, id: \.tag) { 节点 in
                        节点卡片(
                            节点: 节点,
                            选中: 组.selected == 节点.tag,
                            可手动切换: 可手动切换,
                            切换回调: { 切换节点回调(节点.tag) }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - 节点双卡片

/// 节点双卡片
private struct 节点卡片: View {
    /// 节点数据
    let 节点: OutboundGroupItem

    /// 是否当前选中
    let 选中: Bool

    /// 是否可手动切换
    let 可手动切换: Bool

    /// 点击切换回调
    let 切换回调: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：协议标签 + 选中标记
            HStack(spacing: 4) {
                Text(节点.displayType.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                    .cornerRadius(圆角常量.小)

                Spacer()

                if 选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                }
            }

            // 第二行：节点名称
            Text(节点.tag)
                .font(.system(size: 13, weight: 选中 ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 第三行：协议类型说明
            Text(节点.type)
                .font(.system(size: 11))
                .foregroundColor(.次要文字)
                .lineLimit(1)

            Spacer(minLength: 0)

            // 第四行：延迟徽章
            HStack(spacing: 4) {
                if 节点.urlTestDelay > 0 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(节点延迟颜色(节点.urlTestDelay))
                    Text("\(节点.urlTestDelay)ms")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(节点延迟颜色(节点.urlTestDelay))
                } else {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.次要文字)
                    Text("未测速")
                        .font(.system(size: 11))
                        .foregroundColor(.次要文字)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(height: 100, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.卡片背景)
        .cornerRadius(圆角常量.标准)
        .overlay(
            RoundedRectangle(cornerRadius: 圆角常量.标准)
                .stroke(选中 ? Color.主题色 : Color.clear, lineWidth: 2)
        )
        .opacity(可手动切换 ? 1.0 : 0.7)
        .contentShape(Rectangle())
        .onTapGesture {
            guard 可手动切换 else { return }
            切换回调()
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        节点内容区()
            .environmentObject(新UI状态())
    }
    .background(Color.页面背景)
}
