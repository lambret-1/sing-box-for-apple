//
//  节点内容区.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  节点列表内容区：搜索栏 + 分组节点列表 + 延迟徽章 + 选中状态
//  TODO: 第六阶段对接官方 CommandClient 数据
//

import SwiftUI

// MARK: - 占位数据模型

/// 占位节点行数据（骨架阶段静态数据）
/// TODO: 第六阶段替换为官方 CommandClient 返回的节点模型
private struct 占位节点项: Identifiable {
    let id = UUID()
    /// 节点名称
    let 名称: String
    /// 协议标签（vless / vmess / trojan / ss）
    let 协议: String
    /// 服务器地址:端口
    let 地址端口: String
    /// 延迟（毫秒），nil 表示未测速
    let 延迟毫秒: Int?
    /// 是否当前选中
    let 是否选中: Bool
}

/// 占位节点分组数据（骨架阶段静态数据）
private struct 占位节点分组: Identifiable {
    let id = UUID()
    /// 分组名称（订阅名）
    let 名称: String
    /// 组内节点列表
    var 节点列表: [占位节点项]
    /// 是否展开
    var 是否展开: Bool
}

// MARK: - 节点内容区视图

/// 节点内容区视图
struct 节点内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 搜索关键词
    @State private var 搜索关键词 = ""

    /// 占位分组数据
    // TODO: 第六阶段对接官方 CommandClient 数据
    @State private var 分组列表: [占位节点分组] = [
        占位节点分组(
            名称: "官方订阅-香港",
            节点列表: [
                占位节点项(名称: "香港 01", 协议: "vless", 地址端口: "hk01.example.com:443", 延迟毫秒: 42, 是否选中: true),
                占位节点项(名称: "香港 02", 协议: "vmess", 地址端口: "hk02.example.com:443", 延迟毫秒: 58, 是否选中: false),
                占位节点项(名称: "香港 03", 协议: "trojan", 地址端口: "hk03.example.com:443", 延迟毫秒: 120, 是否选中: false),
                占位节点项(名称: "香港 04", 协议: "ss", 地址端口: "hk04.example.com:8388", 延迟毫秒: nil, 是否选中: false)
            ],
            是否展开: true
        ),
        占位节点分组(
            名称: "官方订阅-日本",
            节点列表: [
                占位节点项(名称: "东京 01", 协议: "vless", 地址端口: "jp01.example.com:443", 延迟毫秒: 86, 是否选中: false),
                占位节点项(名称: "东京 02", 协议: "vmess", 地址端口: "jp02.example.com:443", 延迟毫秒: 95, 是否选中: false),
                占位节点项(名称: "大阪 01", 协议: "trojan", 地址端口: "os01.example.com:443", 延迟毫秒: 260, 是否选中: false)
            ],
            是否展开: false
        ),
        占位节点分组(
            名称: "官方订阅-美国",
            节点列表: [
                占位节点项(名称: "洛杉矶 01", 协议: "vless", 地址端口: "us01.example.com:443", 延迟毫秒: 180, 是否选中: false),
                占位节点项(名称: "硅谷 01", 协议: "ss", 地址端口: "us02.example.com:8388", 延迟毫秒: nil, 是否选中: false)
            ],
            是否展开: false
        )
    ]

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 搜索栏骨架
            搜索栏

            // 分组列表
            if 过滤后分组.isEmpty {
                // TODO: 替换为组件/EmptyStateView.swift 中的 EmptyStateView
                EmptyStateView(
                    图标: "server.rack",
                    标题: "暂无节点",
                    说明: "请在「配置管理」中添加远程订阅并更新"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 间距常量.中等) {
                        ForEach($分组列表) { $分组 in
                            分组卡片(分组: $分组)
                        }
                    }
                    .padding(.horizontal, 间距常量.标准)
                    .padding(.bottom, 间距常量.标准)
                }
            }
        }
    }

    // MARK: - 搜索栏

    private var 搜索栏: some View {
        HStack(spacing: 间距常量.紧凑) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.次要文字)
            TextField("搜索节点名称或地址", text: $搜索关键词)
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
        .padding(.horizontal, 间距常量.标准)
    }

    // MARK: - 搜索过滤

    private var 过滤后分组: [占位节点分组] {
        guard !搜索关键词.isEmpty else { return 分组列表 }
        let 关键词 = 搜索关键词.lowercased()
        return 分组列表.compactMap { 分组 in
            let 过滤节点 = 分组.节点列表.filter { 节点 in
                节点.名称.lowercased().contains(关键词) ||
                节点.地址端口.lowercased().contains(关键词)
            }
            guard !过滤节点.isEmpty else { return nil }
            var 新分组 = 分组
            新分组.节点列表 = 过滤节点
            return 新分组
        }
    }
}

// MARK: - 分组卡片

/// 节点分组卡片（可展开/收起）
private struct 分组卡片: View {
    @Binding var 分组: 占位节点分组

    /// 双卡片网格列定义
    private let 网格列 = [
        GridItem(.flexible(), spacing: 间距常量.紧凑),
        GridItem(.flexible(), spacing: 间距常量.紧凑)
    ]

    var body: some View {
        VStack(spacing: 间距常量.紧凑) {
            // 分组标题行
            HStack(spacing: 间距常量.紧凑) {
                // 分组测速按钮骨架
                Button {
                    // TODO: 第六阶段对接分组批量测速
                } label: {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.主题色)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())

                Text(分组.名称)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // 节点数量 + 展开箭头
                HStack(spacing: 6) {
                    Text("\(分组.节点列表.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.次要文字)
                    Image(systemName: 分组.是否展开 ? "chevron.up" : "chevron.down")
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
                withAnimation(.easeInOut(duration: 动画常量.标准)) {
                    分组.是否展开.toggle()
                }
            }

            // 展开的节点双卡片网格
            if 分组.是否展开 {
                LazyVGrid(columns: 网格列, spacing: 间距常量.紧凑) {
                    ForEach(分组.节点列表) { 节点 in
                        节点卡片(节点: 节点)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - 节点卡片

/// 节点双卡片
private struct 节点卡片: View {
    /// 节点数据
    let 节点: 占位节点项

    /// 延迟颜色（按毫秒分级）
    private var 延迟颜色: Color {
        guard let 延迟 = 节点.延迟毫秒 else { return .次要文字 }
        if 延迟 < 100 { return .成功色 }
        if 延迟 < 300 { return .警告色 }
        return .危险色
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：协议标签 + 选中标记
            HStack(spacing: 4) {
                Text(节点.协议.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(节点.是否选中 ? Color.主题色 : Color.主题色.opacity(0.7))
                    .cornerRadius(圆角常量.小)

                Spacer()

                if 节点.是否选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.主题色)
                }
            }

            // 第二行：节点名称
            Text(节点.名称)
                .font(.system(size: 13, weight: 节点.是否选中 ? .semibold : .regular))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 第三行：地址:端口
            Text(节点.地址端口)
                .font(.system(size: 11))
                .foregroundColor(.次要文字)
                .lineLimit(1)

            Spacer(minLength: 0)

            // 第四行：延迟徽章
            HStack(spacing: 4) {
                if let 延迟 = 节点.延迟毫秒 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(延迟颜色)
                    Text("\(延迟)ms")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(延迟颜色)
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
                .stroke(节点.是否选中 ? Color.主题色 : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        // TODO: 第六阶段对接节点切换逻辑
        .onTapGesture { }
        // 右侧滑动测速按钮骨架（拖出操作）
        .contextMenu {
            Button {
                // TODO: 第六阶段对接单节点测速
            } label: {
                Label("测试延迟", systemImage: "gauge")
            }
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
