//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  重构：直接使用官方 LogView，保留完整的日志查看功能
//  官方 LogView 使用 UITextView（UIViewRepresentable）显示日志文本
//  关键：必须给明确高度，否则在外层 ScrollView 中高度计算为0导致不显示
//

import SwiftUI
import ApplicationLibrary
import Library

// MARK: - 规则与日志内容区入口

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

            // 官方日志视图 - 必须给明确高度
            // 使用 GeometryReader 获取可用高度，确保 UITextView 能正常计算布局
            GeometryReader { 几何 in
                LogView()
                    .environmentObject(环境)
                    .frame(width: 几何.size.width, height: 几何.size.height)
                    .background(Color.页面背景)
            }
            // 给一个最小高度，确保在 ScrollView 中不会被压缩为0
            .frame(minHeight: UIScreen.main.bounds.height * 0.55)
        }
        .background(Color.页面背景)
    }
}

// MARK: - 预览

#Preview {
    规则与日志内容区()
        .environmentObject(新UI状态())
        .environmentObject(ExtensionEnvironments())
        .background(Color.页面背景)
}
