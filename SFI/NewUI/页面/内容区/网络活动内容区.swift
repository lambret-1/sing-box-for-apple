//
//  网络活动内容区.swift
//  sing-box-for-apple 新UI
//
//  第六阶段B - 对接官方 CommandClient 真实数据
//  网络活动内容区：顶部统计卡片 + 连接记录列表（实时刷新）
//

import SwiftUI
import Libbox
import Library

// MARK: - 字节格式化辅助

/// 格式化字节数为可读字符串（B / KB / MB / GB）
/// - Parameter 字节: 字节数
/// - Returns: 格式化后的字符串，如 "1.2MB"
private func 格式化字节(_ 字节: Int64) -> String {
    if 字节 < 1024 {
        return "\(字节)B"
    } else if 字节 < 1024 * 1024 {
        return String(format: "%.1fKB", Double(字节) / 1024)
    } else if 字节 < 1024 * 1024 * 1024 {
        return String(format: "%.1fMB", Double(字节) / (1024 * 1024))
    } else {
        return String(format: "%.2fGB", Double(字节) / (1024 * 1024 * 1024))
    }
}

// MARK: - 网络活动内容区视图

/// 网络活动内容区视图
struct 网络活动内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 搜索关键词
    @State private var 搜索关键词 = ""

    /// 命令客户端（ObservableObject，其 @Published 属性变化自动触发刷新）
    private var 命令客户端: CommandClient? { 状态.命令客户端 }

    /// 原始连接列表（官方数据，未加载时为 nil）
    private var 原始连接: [LibboxConnection]? { 命令客户端?.connections }

    /// 过滤后的连接列表
    private var 过滤后连接: [LibboxConnection] {
        guard let 列表 = 原始连接 else { return [] }
        guard !搜索关键词.isEmpty else { return 列表 }
        let 关键词 = 搜索关键词.lowercased()
        return 列表.filter { 连接 in
            连接.destination.lowercased().contains(关键词)
                || 连接.domain.lowercased().contains(关键词)
                || 连接.source.lowercased().contains(关键词)
        }
    }

    /// 连接总数
    private var 连接总数: Int { 原始连接?.count ?? 0 }

    /// 活跃连接数（closedAt == 0 表示未关闭）
    private var 活跃连接数: Int {
        原始连接?.filter { $0.closedAt == 0 }.count ?? 0
    }

    /// 总下载字节（聚合 downlinkTotal）
    private var 总下载字节: Int64 {
        原始连接?.reduce(Int64(0)) { $0 + $1.downlinkTotal } ?? 0
    }

    /// 总上传字节（聚合 uplinkTotal）
    private var 总上传字节: Int64 {
        原始连接?.reduce(Int64(0)) { $0 + $1.uplinkTotal } ?? 0
    }

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 顶部统计卡片（四宫格）
            顶部统计区

            // 搜索栏
            搜索栏

            // 连接记录列表
            if 原始连接 == nil {
                // 数据未加载
                ProgressView("正在加载连接数据…")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if 过滤后连接.isEmpty {
                EmptyStateView(
                    图标: "network",
                    标题: 搜索关键词.isEmpty ? "启动隧道后显示网络活动" : "未找到匹配的连接",
                    说明: 搜索关键词.isEmpty ? "VPN 隧道建立后将实时展示连接列表" : "尝试更换搜索关键词"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(过滤后连接, id: \.id_) { 连接 in
                        连接记录行(连接: 连接)
                        if 连接.id_ != 过滤后连接.last?.id_ {
                            Divider()
                                .padding(.leading, 15)
                        }
                    }
                }
                .background(Color.卡片背景)
                .cornerRadius(圆角常量.标准)
            }
        }
        .padding(.horizontal, 间距常量.标准)
    }

    // MARK: - 搜索栏

    private var 搜索栏: some View {
        HStack(spacing: 间距常量.紧凑) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.次要文字)
            TextField("搜索目标地址 / 域名", text: $搜索关键词)
                .font(.system(size: 14))
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
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

    // MARK: - 顶部统计区

    /// 顶部四宫格统计卡片
    private var 顶部统计区: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 间距常量.中等),
            GridItem(.flexible(), spacing: 间距常量.中等)
        ], spacing: 间距常量.中等) {
            统计小卡(
                图标: "rectangle.connected.to.line.below",
                图标颜色: Color(red: 0.91, green: 0.36, blue: 0.20),
                标题: "连接总数",
                数值: "\(连接总数)",
                单位: "条"
            )
            统计小卡(
                图标: "circle.fill",
                图标颜色: .成功色,
                标题: "活跃",
                数值: "\(活跃连接数)",
                单位: "条"
            )
            统计小卡(
                图标: "arrow.down.circle",
                图标颜色: Color(red: 0.20, green: 0.55, blue: 0.91),
                标题: "总下载",
                数值: 格式化字节(总下载字节),
                单位: ""
            )
            统计小卡(
                图标: "arrow.up.circle",
                图标颜色: Color(red: 0.56, green: 0.38, blue: 0.95),
                标题: "总上传",
                数值: 格式化字节(总上传字节),
                单位: ""
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.卡片背景)
        .cornerRadius(圆角常量.标准)
    }

    /// 单个统计小卡片
    private func 统计小卡(图标: String, 图标颜色: Color, 标题: String, 数值: String, 单位: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: 图标)
                    .font(.system(size: 14))
                    .foregroundColor(图标颜色)
                Text(标题)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.次要文字)
            }
            Text(数值)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            // 占位高度
            Color.clear.frame(height: 6)
            Text(单位)
                .font(.system(size: 10))
                .foregroundColor(.次要文字)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.页面背景)
        .cornerRadius(圆角常量.标准)
    }
}

// MARK: - 连接记录行

/// 单个网络连接记录行
private struct 连接记录行: View {
    /// 连接数据（Libbox 框架类型）
    let 连接: LibboxConnection

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式
    }()

    /// 是否已关闭
    private var 已关闭: Bool { 连接.closedAt > 0 }

    /// 网络类型标签颜色
    private var 网络颜色: Color {
        连接.network.lowercased() == "udp"
            ? Color(red: 0.20, green: 0.55, blue: 0.91)
            : Color(red: 0.91, green: 0.36, blue: 0.20)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：时间 + 协议 + 状态点 + 状态文字
            HStack {
                Text(时间格式.string(from: Date(timeIntervalSince1970: Double(连接.createdAt) / 1000)))
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
                Text(连接.network.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(网络颜色)
                    .cornerRadius(圆角常量.小)
                // 连接状态点
                Circle()
                    .fill(已关闭 ? Color.次要文字 : Color.成功色)
                    .frame(width: 8, height: 8)
                Text(已关闭 ? "已关闭" : "活跃")
                    .font(.system(size: 11))
                    .foregroundColor(已关闭 ? .次要文字 : .成功色)
                Spacer()
            }

            // 第二行：目标地址（优先 displayDestination，含域名）
            Text(连接.displayDestination())
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 第三行：来源地址
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundColor(.次要文字)
                Text(连接.source)
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
                    .lineLimit(1)
            }

            // 第四行：规则 / 出站 + 上下行流量
            HStack {
                if !连接.rule.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(连接.rule)
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(连接.outbound)
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                            .lineLimit(1)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(格式化字节(连接.downlinkTotal))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.次要文字)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(格式化字节(连接.uplinkTotal))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.次要文字)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        网络活动内容区()
            .environmentObject(新UI状态())
    }
    .background(Color.页面背景)
}
