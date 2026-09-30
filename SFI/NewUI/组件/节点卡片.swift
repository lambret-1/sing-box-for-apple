//
//  组件/节点卡片.swift
//  sing-box-for-apple 新UI
//
//  VLESS 节点卡片：收起显示摘要，展开显示可编辑表单 + JSON 预览
//

import SwiftUI

/// VLESS 节点卡片
struct VLESS节点卡片: View {
    /// 转换器全局状态
    @ObservedObject var 状态: VLESS转换器状态
    /// 当前节点项
    let 项: 转换节点项
    /// 是否展开详情
    @Binding var 展开: Bool

    // MARK: 编辑用本地临时状态（展开时初始化）
    @State private var 编辑名称: String = ""
    @State private var 编辑服务器: String = ""
    @State private var 编辑端口: String = ""
    @State private var 编辑UUID: String = ""
    @State private var 编辑路径: String = ""
    @State private var 编辑Host: String = ""
    @State private var 编辑SNI: String = ""
    @State private var 编辑指纹: String = ""

    /// 是否显示已复制提示
    @State private var 已复制: Bool = false

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 间距常量.中等) {
                收起摘要行
                标签行
                if case .失败(let 原因) = 项.解析结果 {
                    错误原因行(原因: 原因)
                }
                if 展开 {
                    Divider().background(Color.分割线)
                    可编辑表单
                    Divider().background(Color.分割线)
                    JSON预览区
                }
            }
            .onChange(of: 展开) { 新值 in
                if 新值, let c = 项.节点配置 {
                    同步编辑状态(c)
                }
            }
        }
    }

    // MARK: 收起摘要

    /// 第一行：选中框 + 名称 + 状态徽章
    private var 收起摘要行: some View {
        HStack(spacing: 间距常量.紧凑) {
            // 选中框（仅成功节点）
            if 项.节点配置 != nil {
                Image(systemName: 是否选中 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(是否选中 ? .主题色 : .次要文字)
                    .onTapGesture {
                        toggle选中()
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(显示名称)
                    .font(字体层级.卡片标题)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let c = 项.节点配置 {
                    Text("\(c.服务器):\(c.端口)")
                        .font(字体层级.正文)
                        .foregroundColor(.次要文字)
                }
            }

            Spacer()

            // 状态徽章
            if case .成功 = 项.解析结果 {
                StateBadge(文字: "成功", 类型: .成功, 带圆点: true)
            } else {
                StateBadge(文字: "失败", 类型: .错误, 带圆点: true)
            }

            Image(systemName: 展开 ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.次要文字)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 动画常量.快速)) {
                展开.toggle()
            }
        }
    }

    /// 第二行：标签行
    private var 标签行: some View {
        HStack(spacing: 间距常量.紧凑) {
            StateBadge(文字: "VLESS", 类型: .信息, 带圆点: false)
            if let c = 项.节点配置 {
                StateBadge(文字: c.传输类型.rawValue.uppercased(), 类型: .信息, 带圆点: false)
                StateBadge(文字: c.安全类型.rawValue.uppercased(), 类型: 安全徽章类型(c.安全类型), 带圆点: false)
                if !c.flow.isEmpty {
                    StateBadge(文字: "VISION", 类型: .警告, 带圆点: false)
                }
            }
            Spacer()
        }
    }

    /// 错误原因行
    private func 错误原因行(原因: String) -> some View {
        HStack(spacing: 间距常量.紧凑) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.危险色)
                .font(.system(size: 12))
            Text(原因)
                .font(字体层级.辅助说明)
                .foregroundColor(.危险色)
            Spacer()
        }
    }

    // MARK: 展开详情

    /// 可编辑表单
    private var 可编辑表单: some View {
        VStack(spacing: 0) {
            AppFormRow(标签: "名称") {
                TextField("节点名称", text: $编辑名称)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onChange(of: 编辑名称) { _ in 触发更新() }
            }
            Divider().background(Color.分割线)

            AppFormRow(标签: "服务器") {
                TextField("example.com", text: $编辑服务器)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .onChange(of: 编辑服务器) { _ in 触发更新() }
            }
            Divider().background(Color.分割线)

            AppFormRow(标签: "端口") {
                TextField("443", text: $编辑端口)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .onChange(of: 编辑端口) { _ in 触发更新() }
            }
            Divider().background(Color.分割线)

            AppFormRow(标签: "UUID") {
                TextField("uuid", text: $编辑UUID)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onChange(of: 编辑UUID) { _ in 触发更新() }
            }

            // 路径（有路径参数时显示）
            if let c = 项.节点配置, 需要显示路径(c.传输类型) {
                Divider().background(Color.分割线)
                AppFormRow(标签: "路径") {
                    TextField("/path", text: $编辑路径)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                        .onChange(of: 编辑路径) { _ in 触发更新() }
                }
            }

            // Host
            Divider().background(Color.分割线)
            AppFormRow(标签: "Host") {
                TextField("host", text: $编辑Host)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .onChange(of: 编辑Host) { _ in 触发更新() }
            }

            // SNI（tls/reality 时显示）
            if let c = 项.节点配置, c.安全类型 == .tls || c.安全类型 == .reality {
                Divider().background(Color.分割线)
                AppFormRow(标签: "SNI") {
                    TextField("sni", text: $编辑SNI)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                        .onChange(of: 编辑SNI) { _ in 触发更新() }
                }
            }

            // 指纹（tls/reality 时显示）
            if let c = 项.节点配置, c.安全类型 == .tls || c.安全类型 == .reality {
                Divider().background(Color.分割线)
                AppFormRow(标签: "指纹") {
                    TextField("chrome", text: $编辑指纹)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .onChange(of: 编辑指纹) { _ in 触发更新() }
                }
            }
        }
    }

    /// JSON 预览区
    private var JSON预览区: some View {
        VStack(alignment: .leading, spacing: 间距常量.紧凑) {
            HStack {
                Text("生成的 sing-box 配置")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                Spacer()
                Button {
                    UIPasteboard.general.string = 项.生成JSON ?? ""
                    已复制 = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        已复制 = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: 已复制 ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(已复制 ? "已复制" : "复制 JSON")
                            .font(字体层级.辅助说明)
                    }
                    .foregroundColor(.主题色)
                }
            }

            ScrollView {
                Text(项.生成JSON ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(间距常量.紧凑)
            }
            .frame(maxHeight: 200)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 圆角常量.小))
        }
    }

    // MARK: 辅助

    /// 显示名称
    private var 显示名称: String {
        if let c = 项.节点配置 {
            return c.名称.isEmpty ? "\(c.服务器):\(c.端口)" : c.名称
        }
        return "行 \(项.行号)"
    }

    /// 是否选中（从全局选中集合读取）
    private var 是否选中: Bool {
        状态.选中集合.contains(项.id)
    }

    /// 安全类型徽章颜色
    private func 安全徽章类型(_ t: 安全类型) -> StateBadge类型 {
        switch t {
        case .none: return .信息
        case .tls: return .警告
        case .reality: return .信息
        }
    }

    /// 是否需要显示路径字段
    private func 需要显示路径(_ t: 传输类型) -> Bool {
        switch t {
        case .ws, .http, .httpupgrade, .splithttp: return true
        case .tcp, .grpc: return false
        }
    }

    /// 切换选中状态
    private func toggle选中() {
        if 状态.选中集合.contains(项.id) {
            状态.选中集合.remove(项.id)
        } else {
            状态.选中集合.insert(项.id)
        }
    }

    /// 把节点配置同步到本地编辑状态
    private func 同步编辑状态(_ c: 节点配置) {
        编辑名称 = c.名称
        编辑服务器 = c.服务器
        编辑端口 = String(c.端口)
        编辑UUID = c.uuid
        编辑路径 = c.路径
        编辑Host = c.Host
        编辑SNI = c.sni
        编辑指纹 = c.指纹
    }

    /// 触发更新：把编辑中的字段写回节点配置并重新生成 JSON
    private func 触发更新() {
        guard var c = 项.节点配置 else { return }
        c.名称 = 编辑名称
        c.服务器 = 编辑服务器
        c.端口 = Int(编辑端口) ?? c.端口
        c.uuid = 编辑UUID
        c.路径 = 编辑路径
        c.Host = 编辑Host
        c.sni = 编辑SNI
        c.指纹 = 编辑指纹
        状态.更新节点配置(项.id, 新配置: c)
    }
}
