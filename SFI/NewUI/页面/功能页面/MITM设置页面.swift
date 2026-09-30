//
//  页面/功能页面/MITM设置页面.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  HTTPS 中间人解密设置页面骨架：MITM 开关、证书状态、证书操作、排除域名列表
//

import SwiftUI

// MARK: - 页面主体

/// MITM 设置页面骨架
///
/// 通过 NavigationLink 从配置管理弹窗 push 进入，导航栈由外层弹窗容器提供。
struct MITM设置页面: View {
    /// 是否启用 MITM（骨架占位状态）
    @State private var 启用MITM = false
    /// 提示文案（占位按钮点击后弹出）
    @State private var 提示: String?

    // TODO: 第六阶段对接官方 MITM 配置
    /// 排除域名列表（静态占位，3 条）
    private let 排除域名列表: [String] = [
        "*.apple.com",
        "*.icloud.com",
        "*.microsoft.com"
    ]

    var body: some View {
        List {
            // MARK: 开关 Section
            Section {
                AppFormRow(标签: "启用 MITM", 说明: "解密 HTTPS 流量以进行抓包与重写（需安装根证书）") {
                    Toggle("", isOn: $启用MITM).labelsHidden()
                }
            }

            // MARK: 证书状态
            Section("证书状态") {
                HStack(spacing: 间距常量.中等) {
                    Image(systemName: "lock.slash")
                        .foregroundColor(.警告色)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未安装证书")
                            .font(字体层级.正文)
                            .foregroundColor(.primary)
                        Text("MITM 解密需要先在系统中信任根证书")
                            .font(字体层级.辅助说明)
                            .foregroundColor(.次要文字)
                    }
                    Spacer()
                    StateBadge(文字: "未安装", 类型: .警告, 带圆点: true)
                }
                .padding(.vertical, 间距常量.紧凑 / 2)
            }

            // MARK: 证书操作
            Section("证书操作") {
                证书操作行(图标: "arrow.down.doc", 标题: "生成证书", 说明: "生成新的 MITM 根证书") {
                    提示 = "后续阶段支持"
                }
                证书操作行(图标: "square.and.arrow.up", 标题: "导出证书", 说明: "导出 .cer 文件用于手动安装") {
                    提示 = "后续阶段支持"
                }
                证书操作行(图标: "graduationcap", 标题: "安装引导", 说明: "跳转系统设置完成证书信任") {
                    提示 = "后续阶段支持"
                }
            }

            // MARK: 排除域名列表
            Section("排除域名（不解密）") {
                ForEach(排除域名列表, id: \.self) { 域名 in
                    HStack(spacing: 间距常量.中等) {
                        Image(systemName: "nosign")
                            .foregroundColor(.次要文字)
                            .frame(width: 24)
                        Text(域名)
                            .font(字体层级.正文)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("MITM 解密")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    提示 = "后续阶段支持"
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加排除域名")
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

/// 证书操作行：图标 + 标题 + 说明 + 点击触发
private struct 证书操作行: View {
    /// SF Symbols 图标
    let 图标: String
    /// 标题
    let 标题: String
    /// 说明
    let 说明: String
    /// 点击回调
    let 动作: () -> Void

    var body: some View {
        Button {
            动作()
        } label: {
            HStack(spacing: 间距常量.中等) {
                Image(systemName: 图标)
                    .foregroundColor(.主题色)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(标题)
                        .font(字体层级.正文)
                        .foregroundColor(.primary)
                    Text(说明)
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
            }
            .padding(.vertical, 间距常量.紧凑 / 2)
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        MITM设置页面()
    }
}
