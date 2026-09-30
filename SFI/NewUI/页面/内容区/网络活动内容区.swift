//
//  网络活动内容区.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  网络活动内容区：顶部统计卡片 + 连接记录列表
//  TODO: 第六阶段对接官方 CommandClient 数据
//

import SwiftUI

// MARK: - 占位数据模型

/// 占位网络连接记录
private struct 占位连接记录: Identifiable {
    let id = UUID()
    /// 序号
    let 序号: Int
    /// 协议（TCP / UDP）
    let 协议: String
    /// 域名（可选）
    let 域名: String?
    /// 远程地址
    let 远程地址: String
    /// 远程端口
    let 远程端口: Int
    /// 开始时间
    let 开始时间: Date
    /// 是否已关闭
    let 已关闭: Bool
    /// 匹配规则名
    let 匹配规则: String?
    /// 出站策略（direct / 代理组名）
    let 出站策略: String
    /// 上行字节
    let 上行字节: Int64
    /// 下行字节
    let 下行字节: Int64
    /// HTTP 状态码（可选）
    let 状态码: Int?
}

// MARK: - 网络活动内容区视图

/// 网络活动内容区视图
struct 网络活动内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 占位连接记录列表
    // TODO: 第六阶段对接官方 CommandClient 数据
    @State private var 连接列表: [占位连接记录] = [
        占位连接记录(
            序号: 1024, 协议: "TCP", 域名: "www.apple.com",
            远程地址: "17.253.144.10", 远程端口: 443,
            开始时间: Date().addingTimeInterval(-12),
            已关闭: false, 匹配规则: "苹果服务",
            出站策略: "代理选择", 上行字节: 2048, 下行字节: 156_000,
            状态码: 200
        ),
        占位连接记录(
            序号: 1023, 协议: "TCP", 域名: "api.github.com",
            远程地址: "140.82.121.3", 远程端口: 443,
            开始时间: Date().addingTimeInterval(-45),
            已关闭: false, 匹配规则: "开发工具",
            出站策略: "代理选择", 上行字节: 5_120, 下行字节: 88_000,
            状态码: 301
        ),
        占位连接记录(
            序号: 1022, 协议: "UDP", 域名: "dns.google",
            远程地址: "8.8.8.8", 远程端口: 53,
            开始时间: Date().addingTimeInterval(-90),
            已关闭: true, 匹配规则: "DNS",
            出站策略: "direct", 上行字节: 96, 下行字节: 168,
            状态码: nil
        ),
        占位连接记录(
            序号: 1021, 协议: "TCP", 域名: "cdn.jsdelivr.net",
            远程地址: "104.16.87.20", 远程端口: 443,
            开始时间: Date().addingTimeInterval(-150),
            已关闭: true, 匹配规则: "CDN",
            出站策略: "direct", 上行字节: 3_072, 下行字节: 2_048_000,
            状态码: 200
        ),
        占位连接记录(
            序号: 1020, 协议: "TCP", 域名: nil,
            远程地址: "203.0.113.7", 远程端口: 8080,
            开始时间: Date().addingTimeInterval(-240),
            已关闭: true, 匹配规则: nil,
            出站策略: "自动测速", 上行字节: 512, 下行字节: 0,
            状态码: 502
        )
    ]

    /// TCP 连接数
    private var tcp数量: Int {
        连接列表.filter { $0.协议 == "TCP" }.count
    }

    /// 活跃连接数
    private var 活跃连接数: Int {
        连接列表.filter { !$0.已关闭 }.count
    }

    var body: some View {
        VStack(spacing: 间距常量.中等) {
            // 顶部统计卡片（四宫格）
            顶部统计区

            // 连接记录列表
            if 连接列表.isEmpty {
                EmptyStateView(
                    图标: "network",
                    标题: "暂无网络连接",
                    说明: "启动 VPN 后将显示实时连接信息"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(连接列表) { 连接 in
                        连接记录行(连接: 连接)
                        if 连接.id != 连接列表.last?.id {
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
                标题: "TCP",
                数值: "\(tcp数量)",
                单位: "连接"
            )
            统计小卡(
                图标: "circle.fill",
                图标颜色: .成功色,
                标题: "活跃",
                数值: "\(活跃连接数)",
                单位: "连接"
            )
            统计小卡(
                图标: "arrow.down.circle",
                图标颜色: Color(red: 0.20, green: 0.55, blue: 0.91),
                标题: "下行",
                数值: "2.4",
                单位: "MB"
            )
            统计小卡(
                图标: "arrow.up.circle",
                图标颜色: Color(red: 0.56, green: 0.38, blue: 0.95),
                标题: "上行",
                数值: "10.8",
                单位: "KB"
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
                .font(.system(size: 22, weight: .bold))
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
    /// 连接数据
    let 连接: 占位连接记录

    /// 时间格式化器
    private let 时间格式: DateFormatter = {
        let 格式 = DateFormatter()
        格式.dateFormat = "HH:mm:ss"
        return 格式
    }()

    /// 状态码颜色
    private var 状态码颜色: Color {
        guard let 码 = 连接.状态码 else { return .次要文字 }
        if 码 >= 200 && 码 < 300 { return .成功色 }
        if 码 >= 300 && 码 < 400 { return .主题色 }
        if 码 >= 400 && 码 < 500 { return .警告色 }
        if 码 >= 500 { return .危险色 }
        return .次要文字
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：时间 + 协议 + 状态点 + 状态码
            HStack {
                Text(时间格式.string(from: 连接.开始时间))
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
                Text(连接.协议)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(连接.协议 == "TCP" ? Color(red: 0.91, green: 0.36, blue: 0.20) : Color(red: 0.20, green: 0.55, blue: 0.91))
                    .cornerRadius(圆角常量.小)
                // 连接状态点
                Circle()
                    .fill(连接.已关闭 ? Color.次要文字 : Color.成功色)
                    .frame(width: 8, height: 8)
                Spacer()
                if let 码 = 连接.状态码 {
                    Text("\(码)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(状态码颜色)
                }
                Text("#\(连接.序号)")
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
            }

            // 第二行：域名/地址
            Text("\(连接.域名 ?? 连接.远程地址):\(连接.远程端口)")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 第三行：规则标签
            if let 规则 = 连接.匹配规则, !规则.isEmpty {
                Text(规则)
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
                    .lineLimit(1)
            }

            // 第四行：出站策略 + 上下行流量
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: 连接.出站策略 == "direct" ? "arrow.right" : "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(连接.出站策略 == "direct" ? .成功色 : .主题色)
                    Text("\(连接.出站策略)")
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                }
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(格式化字节(连接.下行字节))
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                        Text(格式化字节(连接.上行字节))
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // TODO: 第六阶段对接连接详情面板
        .onTapGesture { }
    }

    /// 格式化字节数
    private func 格式化字节(_ 字节: Int64) -> String {
        if 字节 < 1024 {
            return "\(字节)B"
        } else if 字节 < 1024 * 1024 {
            return String(format: "%.1fKB", Double(字节) / 1024)
        } else {
            return String(format: "%.1fMB", Double(字节) / (1024 * 1024))
        }
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
