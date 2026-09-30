//
//  新UI入口视图.swift
//  sing-box-for-apple 新UI
//
//  新UI入口：绑定官方 ExtensionEnvironments，注入 新UI状态，展示仪表盘
//  负责初始化流程：reload 加载 ExtensionProfile → connect 连接 CommandClient
//  作为 Application.swift 的根视图替换官方 MainView
//

import SwiftUI
import NetworkExtension
import Library

/// 新UI入口视图
struct 新UI入口视图: View {
    /// 官方扩展环境（从 Application.swift 注入）
    @EnvironmentObject private var 环境: ExtensionEnvironments

    /// 新UI全局状态（本视图创建并向下注入）
    @StateObject private var 状态 = 新UI状态()

    /// 场景阶段（用于前后台切换时重连 CommandClient）
    @Environment(\.scenePhase) private var 场景阶段

    var body: some View {
        内容视图
            .environmentObject(状态)
            .onAppear {
                // 绑定官方扩展环境
                状态.绑定环境(环境)
                // 加载 ExtensionProfile（从 NETunnelProviderManager 读取）
                Task { @MainActor in
                    await 环境.reload()
                }
            }
            .onChange(of: 场景阶段) { 新阶段 in
                // 从后台返回前台时重连 CommandClient
                guard 新阶段 == .active else { return }
                环境.connect()
            }
            .onReceive(环境.$extensionProfile) { _ in
                // ExtensionProfile 加载完成后尝试连接 CommandClient
                环境.connect()
            }
    }

    // MARK: - 内容视图（根据加载状态分发）

    @ViewBuilder
    private var 内容视图: some View {
        if 环境.extensionProfileLoading {
            // 配置文件加载中
            VStack(spacing: 间距常量.中等) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("正在加载 VPN 配置…")
                    .font(字体层级.正文)
                    .foregroundColor(.次要文字)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.页面背景)
        } else if 环境.extensionProfile == nil {
            // 未安装配置文件，引导安装
            配置安装引导视图()
                .environmentObject(状态)
        } else {
            // 正常展示仪表盘
            仪表盘视图()
                .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
                    // VPN 状态变化时尝试连接 CommandClient
                    环境.connect()
                }
        }
    }
}

// MARK: - 配置安装引导视图

/// 未安装 VPN 配置文件时的引导视图
private struct 配置安装引导视图: View {
    @EnvironmentObject private var 环境: ExtensionEnvironments
    @EnvironmentObject private var 状态: 新UI状态

    var body: some View {
        VStack(spacing: 间距常量.大) {
            Spacer()

            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.次要文字)

            Text("未配置 VPN")
                .font(字体层级.大标题)
                .foregroundColor(.primary)

            Text("需要先安装 VPN 配置文件才能使用隧道功能")
                .font(字体层级.正文)
                .foregroundColor(.次要文字)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 间距常量.大)

            AppButton("安装配置文件", 样式: .主要) {
                Task { @MainActor in
                    await 环境.reload()
                }
            }
            .padding(.horizontal, 间距常量.大)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.页面背景)
    }
}
