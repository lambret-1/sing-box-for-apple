//
//  页面/功能页面/DNS设置页面.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  DNS 功能页面骨架：自定义 DNS 开关、服务器列表、统计卡片、最近查询记录
//

import SwiftUI

// MARK: - 页面主体

/// DNS 设置页面骨架
///
/// 通过 NavigationLink 从配置管理弹窗 push 进入，导航栈由外层弹窗容器提供。
struct DNS设置页面: View {
    /// 是否启用自定义 DNS（骨架占位状态）
    @State private var 启用自定义DNS = true
    /// 提示文案（占位按钮点击后弹出）
    @State private var 提示: String?

    // TODO: 第六阶段对接官方 DNS 配置
    /// DNS 服务器列表（静态占位）
    private let 服务器列表: [DNSServer占位] = [
        DNSServer占位(地址: "114.114.114.114", 类型: "UDP", 备注: "国内公共 DNS"),
        DNSServer占位(地址: "8.8.8.8", 类型: "UDP", 备注: "Google DNS"),
        DNSServer占位(地址: "1.1.1.1", 类型: "DoH", 备注: "Cloudflare DNS")
    ]

    // TODO: 第六阶段对接官方 DNS 配置
    /// 最近查询记录（静态占位，5 条）
    private let 查询记录列表: [DNS记录占位] = [
        DNS记录占位(域名: "www.apple.com", 类型: "A", 响应IP: "17.0.0.1", 耗时: "12ms", 成功: true),
        DNS记录占位(域名: "api.github.com", 类型: "AAAA", 响应IP: "::1", 耗时: "28ms", 成功: true),
        DNS记录占位(域名: "cdn.sing-box.app", 类型: "A", 响应IP: "104.16.80.8", 耗时: "5ms", 成功: true),
        DNS记录占位(域名: "test.example.invalid", 类型: "A", 响应IP: "-", 耗时: "超时", 成功: false),
        DNS记录占位(域名: "dns.google", 类型: "HTTPS", 响应IP: "8.8.8.8", 耗时: "19ms", 成功: true)
    ]

    var body: some View {
        List {
            // MARK: 开关 Section
            Section {
                AppFormRow(标签: "启用自定义 DNS", 说明: "开启后将按下方服务器列表解析域名") {
                    Toggle("", isOn: $启用自定义DNS).labelsHidden()
                }
            }

            // MARK: DNS 服务器列表
            Section("DNS 服务器") {
                ForEach(服务器列表) { 服务器 in
                    HStack(spacing: 间距常量.中等) {
                        Image(systemName: "network")
                            .foregroundColor(.主题色)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(服务器.地址)
                                .font(字体层级.正文)
                                .foregroundColor(.primary)
                            Text(服务器.备注)
                                .font(字体层级.辅助说明)
                                .foregroundColor(.次要文字)
                        }
                        Spacer()
                        StateBadge(文字: 服务器.类型, 类型: .信息, 带圆点: false)
                    }
                }
            }

            // MARK: 统计卡片
            Section("DNS 统计") {
                HStack(spacing: 间距常量.标准) {
                    统计指标(标题: "查询总数", 数值: "12,480", 颜色: .主题色)
                    Divider().frame(height: 40)
                    统计指标(标题: "缓存命中", 数值: "8,320", 颜色: .成功色)
                    Divider().frame(height: 40)
                    统计指标(标题: "平均延迟", 数值: "18ms", 颜色: .警告色)
                }
                .padding(.vertical, 间距常量.紧凑)
            }

            // MARK: 最近查询记录
            Section("最近查询") {
                ForEach(查询记录列表) { 记录 in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(记录.域名)
                                .font(字体层级.正文)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            StateBadge(文字: 记录.类型, 类型: .信息, 带圆点: false)
                        }
                        HStack(spacing: 间距常量.中等) {
                            Text("→ \(记录.响应IP)")
                                .font(字体层级.辅助说明)
                                .foregroundColor(.次要文字)
                            Spacer()
                            Text(记录.耗时)
                                .font(字体层级.辅助说明)
                                .foregroundColor(记录.成功 ? .次要文字 : .危险色)
                            Image(systemName: 记录.成功 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(记录.成功 ? .成功色 : .危险色)
                        }
                    }
                    .padding(.vertical, 间距常量.紧凑 / 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("DNS 设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    提示 = "后续阶段支持"
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加 DNS 服务器")
            }
        }
        .alert("提示", isPresented: Binding(
            get: { 提示 != nil },
            set: { if !$0 { 提示 = nil } }
        )) {
            Button("好", role: .cancel) { 提示 = nil }
        } message: {
            Text(提示 ?? "")
        }
    }
}

// MARK: - 子视图

/// 统计指标：标题 + 数值
private struct 统计指标: View {
    /// 指标标题
    let 标题: String
    /// 指标数值
    let 数值: String
    /// 数值颜色
    let 颜色: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(数值)
                .font(字体层级.数据指标)
                .foregroundColor(颜色)
            Text(标题)
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 静态占位数据模型

/// DNS 服务器占位模型
private struct DNSServer占位: Identifiable {
    /// 唯一标识
    let id = UUID()
    /// 服务器地址
    let 地址: String
    /// 协议类型（UDP / DoH / DoT）
    let 类型: String
    /// 备注说明
    let 备注: String
}

/// DNS 查询记录占位模型
private struct DNS记录占位: Identifiable {
    /// 唯一标识
    let id = UUID()
    /// 查询域名
    let 域名: String
    /// 记录类型（A / AAAA / HTTPS）
    let 类型: String
    /// 响应 IP
    let 响应IP: String
    /// 耗时
    let 耗时: String
    /// 是否成功
    let 成功: Bool
}

// MARK: - 预览

#Preview {
    NavigationStack {
        DNS设置页面()
    }
}
