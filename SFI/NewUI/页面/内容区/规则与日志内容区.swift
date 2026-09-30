//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  重构：直接使用官方 LogView，保留完整的日志查看功能
//  官方视图包含：日志级别筛选、搜索、暂停滚动、复制、导出、清除、远程控制
//

import SwiftUI
import ApplicationLibrary
import Library

// MARK: - 规则与日志内容区视图

/// 规则与日志内容区视图：直接嵌入官方 LogView
struct 规则与日志内容区: View {
    /// 全局新UI状态
    @EnvironmentObject private var 状态: 新UI状态
    /// 官方扩展环境
    @EnvironmentObject private var 环境: ExtensionEnvironments

    var body: some View {
        VStack(spacing: 0) {
            // VPN 未连接提示
            if !状态.是否已连接 {
                HStack(spacing: 间距常量.紧凑) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.警告色)
                        .font(.system(size: 14))
                    Text("VPN 未连接，日志可能未更新")
                        .font(.system(size: 13))
                        .foregroundColor(.警告色)
                    Spacer()
                }
                .padding(.horizontal, 间距常量.标准)
                .padding(.vertical, 8)
            }

            // 官方日志视图
            LogView()
                .environmentObject(环境)
                // 覆盖官方背景色，使用新UI设计系统
                .background(Color.页面背景)
        }
    }
}

// MARK: - 预览

#Preview {
    规则与日志内容区()
        .environmentObject(新UI状态())
        .environmentObject(ExtensionEnvironments())
        .background(Color.页面背景)
}
