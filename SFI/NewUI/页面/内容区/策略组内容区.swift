//
//  策略组内容区.swift
//  sing-box-for-apple 新UI
//
//  重构：直接使用官方 GroupListView，保留完整的策略组管理功能
//  官方视图包含：组展开/收起、节点切换、组内测速、延迟显示
//

import SwiftUI
import ApplicationLibrary
import Library

// MARK: - 策略组内容区视图

/// 策略组内容区视图：直接嵌入官方 GroupListView
struct 策略组内容区: View {
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
                    Text("VPN 未连接，策略组数据可能未更新")
                        .font(.system(size: 13))
                        .foregroundColor(.警告色)
                    Spacer()
                }
                .padding(.horizontal, 间距常量.标准)
                .padding(.vertical, 8)
            }

            // 官方策略组列表视图
            // 官方 GroupListView 内部有 .padding(16)，添加负 padding 抵消以与配置区宽度对齐
            GroupListView()
                .environmentObject(环境)
                .padding(.horizontal, -16)
                // 覆盖官方背景色，使用新UI设计系统
                .background(Color.页面背景)
        }
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        策略组内容区()
            .environmentObject(新UI状态())
            .environmentObject(ExtensionEnvironments())
    }
    .background(Color.页面背景)
}
