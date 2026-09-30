//
//  规则与日志内容区.swift
//  sing-box-for-apple 新UI
//
//  重构：使用 NavigationStack 包裹官方 LogView，显示官方工具栏
//  官方 LogView 使用 UITextView 显示日志文本，toolbar 包含搜索/暂停/菜单
//  日志页不使用外层 ScrollView，占满剩余空间延伸到底部工具栏上方
//

import SwiftUI
import ApplicationLibrary
import Library

// MARK: - 规则与日志内容区入口

/// 规则与日志内容区视图：NavigationStack 包裹官方 LogView
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

            // 官方日志视图 - NavigationStack 包裹以显示 toolbar
            NavigationStack {
                LogView()
                    .environmentObject(环境)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .background(Color.页面背景)
            }
            // 占满剩余空间
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
