//
//  页面/功能页面/重写规则设置页面.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  URL 重写规则设置页面骨架：功能开关、规则分组（请求/响应）、规则行、右上角添加按钮
//

import SwiftUI

// MARK: - 页面主体

/// URL 重写规则设置页面骨架
///
/// 通过 NavigationLink 从配置管理弹窗 push 进入，导航栈由外层弹窗容器提供。
struct 重写规则设置页面: View {
    /// 是否启用重写功能（骨架占位状态）
    @State private var 启用重写 = false
    /// 提示文案（占位按钮点击后弹出）
    @State private var 提示: String?

    // TODO: 第六阶段对接官方重写规则
    /// 规则分组列表（静态占位：请求重写、响应重写）
    private let 分组列表: [规则分组占位] = [
        规则分组占位(
            标题: "请求重写",
            说明: "修改发往服务器的请求",
            规则: [
                规则行占位(匹配URL: "https://api.example.com/v1/*", 操作: "替换 Host", 替换内容: "proxy.example.com"),
                规则行占位(匹配URL: "https://*.analytics.com/*", 操作: "阻断请求", 替换内容: "-")
            ]
        ),
        规则分组占位(
            标题: "响应重写",
            说明: "修改服务器返回的响应",
            规则: [
                规则行占位(匹配URL: "https://cdn.example.com/*.js", 操作: "替换正文", 替换内容: "window.debug=true"),
                规则行占位(匹配URL: "https://api.example.com/status", 操作: "删除响应头", 替换内容: "Server")
            ]
        )
    ]

    var body: some View {
        List {
            // MARK: 开关 Section
            Section {
                AppFormRow(标签: "启用重写功能", 说明: "对匹配的请求或响应执行自定义改写规则") {
                    Toggle("", isOn: $启用重写).labelsHidden()
                }
            }

            // MARK: 规则分组
            ForEach(分组列表) { 分组 in
                Section {
                    ForEach(分组.规则) { 规则 in
                        规则行(规则: 规则)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(分组.标题)
                        Text(分组.说明)
                            .font(字体层级.辅助说明)
                            .foregroundColor(.次要文字)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("重写规则")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    提示 = "后续阶段支持"
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加规则")
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

/// 单条重写规则行：匹配 URL + 操作 + 替换内容 + 启用开关
private struct 规则行: View {
    /// 规则数据
    let 规则: 规则行占位
    /// 是否启用（骨架占位状态）
    @State private var 已启用 = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(规则.匹配URL)
                    .font(字体层级.正文)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Toggle("", isOn: $已启用).labelsHidden()
            }

            HStack(spacing: 间距常量.紧凑) {
                StateBadge(文字: 规则.操作, 类型: .信息, 带圆点: false)
                Text(规则.替换内容)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 间距常量.紧凑 / 2)
    }
}

// MARK: - 静态占位数据模型

/// 规则分组占位模型
private struct 规则分组占位: Identifiable {
    /// 唯一标识
    let id = UUID()
    /// 分组标题
    let 标题: String
    /// 分组说明
    let 说明: String
    /// 分组下的规则列表
    let 规则: [规则行占位]
}

/// 单条规则占位模型
private struct 规则行占位: Identifiable {
    /// 唯一标识
    let id = UUID()
    /// 匹配 URL
    let 匹配URL: String
    /// 操作类型
    let 操作: String
    /// 替换内容
    let 替换内容: String
}

// MARK: - 预览

#Preview {
    NavigationStack {
        重写规则设置页面()
    }
}
