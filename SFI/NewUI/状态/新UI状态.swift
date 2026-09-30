//
//  新UI状态.swift
//  新UI状态管理
//
//  对接官方 ExtensionProfile / CommandClient / ProfileManager 数据层
//  提供新UI所需的导航状态、VPN状态、连接操作
//  不包含任何数据层实现，仅做桥接与UI状态管理
//

import Foundation
import SwiftUI
import NetworkExtension
import Library
import Libbox

// MARK: - 顶部卡片类型

/// 顶部横向功能卡片枚举，对应四个内容区 + 日志
enum 顶部卡片类型: String, CaseIterable, Identifiable {
    case 节点
    case 策略组
    case 网络活动
    case 规则与日志

    var id: String { rawValue }

    /// 卡片显示标题
    var 标题: String {
        switch self {
        case .节点: return "节点"
        case .策略组: return "策略组"
        case .网络活动: return "网络活动"
        case .规则与日志: return "规则日志"
        }
    }

    /// SF Symbols 图标
    var 图标: String {
        switch self {
        case .节点: return "server.rack"
        case .策略组: return "point.3.connected.trianglepath.dotted"
        case .网络活动: return "chart.bar.xaxis"
        case .规则与日志: return "doc.text.magnifyingglass"
        }
    }

    /// 卡片背景渐变色（从新VPN设计还原）
    var 背景色: Color {
        switch self {
        case .节点:
            return Color(light: Color(red: 0.20, green: 0.55, blue: 0.95),
                         dark: Color(red: 0.15, green: 0.40, blue: 0.75))
        case .策略组:
            return Color(light: Color(red: 0.55, green: 0.35, blue: 0.85),
                         dark: Color(red: 0.40, green: 0.25, blue: 0.65))
        case .网络活动:
            return Color(light: Color(red: 0.10, green: 0.65, blue: 0.55),
                         dark: Color(red: 0.08, green: 0.50, blue: 0.42))
        case .规则与日志:
            return Color(light: Color(red: 0.85, green: 0.45, blue: 0.15),
                         dark: Color(red: 0.65, green: 0.35, blue: 0.10))
        }
    }
}

// MARK: - 底部弹窗类型

/// 底部工具栏弹窗类型
enum 底部弹窗类型: String, CaseIterable, Identifiable {
    case 配置
    case 工具
    case 设置
    case 关于

    var id: String { rawValue }

    /// SF Symbols 图标
    var 图标: String {
        switch self {
        case .配置: return "square.stack.3d.up"
        case .工具: return "wrench.and.screwdriver"
        case .设置: return "gearshape"
        case .关于: return "info.circle"
        }
    }

    /// 弹窗标题
    var 标题: String {
        switch self {
        case .配置: return "配置管理"
        case .工具: return "工具"
        case .设置: return "设置"
        case .关于: return "关于"
        }
    }
}

// MARK: - VPN 连接状态（适配 NEVPNStatus）

/// VPN 连接状态的UI层封装，提供中文显示与颜色
enum VPN连接状态 {
    case 已断开
    case 正在连接
    case 已连接
    case 正在断开
    case 无效

    /// 从 NEVPNStatus 转换
    init(_ 状态: NEVPNStatus?) {
        guard let 状态 else {
            self = .无效
            return
        }
        switch 状态 {
        case .invalid: self = .无效
        case .disconnected: self = .已断开
        case .connecting: self = .正在连接
        case .connected: self = .已连接
        case .reasserting: self = .正在连接
        case .disconnecting: self = .正在断开
        @unknown default: self = .无效
        }
    }

    /// 中文显示文字
    var 显示文字: String {
        switch self {
        case .已断开: return "已断开"
        case .正在连接: return "连接中…"
        case .已连接: return "已连接"
        case .正在断开: return "断开中…"
        case .无效: return "未配置"
        }
    }

    /// 是否处于活动状态（连接中或已连接）
    var 是否活动: Bool {
        switch self {
        case .正在连接, .已连接: return true
        default: return false
        }
    }

    /// 状态对应颜色
    var 颜色: Color {
        switch self {
        case .已连接: return .成功色
        case .正在连接, .正在断开: return .警告色
        case .已断开: return .primary
        case .无效: return .次要文字
        }
    }
}

// MARK: - 新UI全局状态

/// 新UI全局状态对象，桥接官方数据层
/// 通过 @EnvironmentObject 注入到新UI视图层级
@MainActor
final class 新UI状态: ObservableObject {
    // MARK: 官方数据层引用

    /// 官方扩展环境（包含 ExtensionProfile / CommandClient）
    private weak var 扩展环境: ExtensionEnvironments?

    // MARK: UI 导航状态

    /// 当前选中的顶部功能卡片
    @Published var 当前顶部卡片: 顶部卡片类型 = .节点

    /// 当前底部弹窗（nil 表示无弹窗）
    @Published var 当前底部弹窗: 底部弹窗类型?

    /// 是否显示运行模式选择面板
    @Published var 显示运行模式面板: Bool = false

    /// 是否正在执行连接/断开操作
    @Published var 操作中: Bool = false

    /// 最近一次操作错误信息
    @Published var 错误信息: String?

    // MARK: 初始化

    init() {}

    /// 绑定官方扩展环境（在入口视图调用）
    func 绑定环境(_ 环境: ExtensionEnvironments) {
        self.扩展环境 = 环境
    }

    // MARK: VPN 状态访问

    /// 当前 VPN 连接状态
    var 当前VPN状态: VPN连接状态 {
        VPN连接状态(扩展环境?.extensionProfile?.status)
    }

    /// VPN 是否已连接
    var 是否已连接: Bool {
        当前VPN状态 == .已连接
    }

    /// 当前连接时长（已连接时）
    var 连接时长: String {
        guard let 日期 = 扩展环境?.extensionProfile?.connectedDate else { return "--:--:--" }
        let 间隔 = Date().timeIntervalSince(日期)
        let 时 = Int(间隔) / 3600
        let 分 = Int(间隔) / 60 % 60
        let 秒 = Int(间隔) % 60
        return String(format: "%02d:%02d:%02d", 时, 分, 秒)
    }

    // MARK: VPN 连接操作

    /// 切换 VPN 连接状态
    func 切换连接() {
        guard !操作中 else { return }
        操作中 = true
        错误信息 = nil

        Task { @MainActor in
            defer { 操作中 = false }
            do {
                if 当前VPN状态.是否活动 {
                    try await 扩展环境?.extensionProfile?.stop()
                } else {
                    try await 扩展环境?.extensionProfile?.start()
                }
            } catch {
                错误信息 = error.localizedDescription
            }
        }
    }

    // MARK: 官方数据层便捷访问

    /// 命令客户端（用于日志、策略组、连接信息）
    var 命令客户端: CommandClient? {
        扩展环境?.commandClient
    }

    // MARK: 节点切换与测速操作

    /// 切换指定策略组的选中节点
    /// - Parameters:
    ///   - 组标签: 策略组标签（OutboundGroup.tag）
    ///   - 节点标签: 目标节点标签（OutboundGroupItem.tag）
    func 切换节点(组标签: String, 节点标签: String) async {
        do {
            let client = try CommandTarget.standaloneClient()
            try await client.selectOutbound(组标签, outboundTag: 节点标签)
        } catch {
            错误信息 = "切换节点失败：\(error.localizedDescription)"
        }
    }

    /// 触发指定策略组的组内批量测速（URL 测试）
    /// - Parameter 组标签: 策略组标签（OutboundGroup.tag）
    func 测速(组标签: String) async {
        do {
            let client = try CommandTarget.standaloneClient()
            try await client.urlTest(组标签)
        } catch {
            错误信息 = "测速失败：\(error.localizedDescription)"
        }
    }
}
