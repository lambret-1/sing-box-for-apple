//
//  新UI入口视图.swift
//  sing-box-for-apple 新UI
//
//  新UI入口：绑定官方 ExtensionEnvironments，注入 新UI状态，展示仪表盘
//  作为 Application.swift 的根视图替换官方 MainView
//

import SwiftUI
import Library

/// 新UI入口视图
struct 新UI入口视图: View {
    /// 官方扩展环境（从 Application.swift 注入）
    @EnvironmentObject private var 环境: ExtensionEnvironments

    /// 新UI全局状态（本视图创建并向下注入）
    @StateObject private var 状态 = 新UI状态()

    var body: some View {
        仪表盘视图()
            .environmentObject(状态)
            .onAppear {
                // 绑定官方扩展环境，使新UI状态可访问 ExtensionProfile / CommandClient
                状态.绑定环境(环境)
            }
    }
}
