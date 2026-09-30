//
//  页面/功能页面/规则集管理页面.swift
//  sing-box-for-apple 新UI
//
//  规则集管理：列表展示、添加/编辑/删除、手动下载、rule_key 提示
//

import SwiftUI

/// 规则集管理页面
struct 规则集管理页面: View {
    /// 规则集管理器
    @StateObject private var 管理器 = 规则集管理器()
    /// 环境关闭
    @Environment(\.dismiss) private var 关闭
    /// 是否显示添加/编辑 sheet
    @State private var 显示编辑表: Bool = false
    /// 正在编辑的规则集（nil 表示新增）
    @State private var 编辑中的配置: 规则集配置?
    /// 是否显示 rule_key 展开
    @State private var 展开ruleKeys: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if 管理器.规则集列表.isEmpty {
                    空态
                } else {
                    ForEach(管理器.规则集列表) { 配置 in
                        规则集行(配置: 配置)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    管理器.删除规则集(配置.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("规则集管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        关闭()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        编辑中的配置 = nil
                        显示编辑表 = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $显示编辑表) {
                编辑规则集表(管理器: 管理器, 编辑中的配置: $编辑中的配置)
            }
            .onAppear {
                管理器.恢复官方预设()
            }
        }
    }

    // MARK: 空态

    private var 空态: some View {
        VStack(spacing: 间距常量.中等) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无规则集")
                .font(字体层级.卡片标题)
                .foregroundColor(.secondary)
            AppButton("恢复官方预设", 样式: .次要, 全宽: false) {
                管理器.恢复官方预设()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: 规则集行

    private func 规则集行(配置: 规则集配置) -> some View {
        VStack(alignment: .leading, spacing: 间距常量.紧凑) {
            // 第一行：tag + 状态徽章
            HStack {
                Text(配置.tag)
                    .font(字体层级.卡片标题)
                    .foregroundColor(.primary)
                Spacer()
                状态徽章(配置.下载状态)
            }

            // 第二行：url
            Text(配置.url)
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
                .lineLimit(2)

            // 第三行：配置信息
            HStack(spacing: 间距常量.紧凑) {
                StateBadge(文字: 配置.format, 类型: .信息, 带圆点: false)
                StateBadge(文字: 配置.download_detour, 类型: .信息, 带圆点: false)
                StateBadge(文字: 配置.update_interval, 类型: .信息, 带圆点: false)
            }

            // 第四行：文件信息 + 更新按钮
            HStack {
                if let 大小 = 配置.文件大小, 配置.下载状态 == .已下载 {
                    Text(格式化文件大小(大小))
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                if let 时间 = 配置.最后更新时间 {
                    Text("· \(时间.formatted(date: .abbreviated, time: .shortened))")
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                Spacer()
                Button {
                    Task { await 管理器.下载规则集(配置.id) }
                } label: {
                    if 管理器.下载中 {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(配置.下载状态 == .已下载 ? "更新" : "下载")
                            .font(字体层级.辅助说明)
                    }
                }
                .foregroundColor(.主题色)
                .disabled(管理器.下载中)
            }

            // rule_key 展开
            DisclosureGroup(isExpanded: Binding(
                get: { 展开ruleKeys.contains(配置.id) },
                set: { 展开 in
                    if 展开 { 展开ruleKeys.insert(配置.id) } else { 展开ruleKeys.remove(配置.id) }
                }
            )) {
                let keys = 管理器.获取可用ruleKeys(配置)
                if keys.isEmpty {
                    Text("暂无提示")
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 间距常量.紧凑)], spacing: 间距常量.紧凑) {
                        ForEach(keys, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.主题色)
                                .padding(.horizontal, 间距常量.紧凑)
                                .padding(.vertical, 4)
                                .background(Color.主题色.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 圆角常量.小))
                                .onTapGesture {
                                    UIPasteboard.general.string = key
                                }
                        }
                    }
                }
            } label: {
                Text("可用 rule_key")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.主题色)
            }
        }
        .padding(.vertical, 间距常量.紧凑)
    }

    // MARK: 辅助

    /// 状态徽章
    private func 状态徽章(_ 状态: 规则集下载状态) -> StateBadge {
        switch 状态 {
        case .已下载:
            return StateBadge(文字: "已下载", 类型: .成功, 带圆点: true)
        case .未下载:
            return StateBadge(文字: "未下载", 类型: .信息, 带圆点: true)
        case .下载失败:
            return StateBadge(文字: "失败", 类型: .错误, 带圆点: true)
        }
    }

    /// 格式化文件大小
    private func 格式化文件大小(_ 字节: Int64) -> String {
        let 字节数 = Double(字节)
        if 字节数 < 1024 { return "\(字节) B" }
        if 字节数 < 1024 * 1024 { return String(format: "%.1f KB", 字节数 / 1024) }
        return String(format: "%.1f MB", 字节数 / (1024 * 1024))
    }
}

// MARK: - 编辑规则集 sheet

/// 添加/编辑规则集表单
private struct 编辑规则集表: View {
    let 管理器: 规则集管理器
    @Binding var 编辑中的配置: 规则集配置?
    @Environment(\.dismiss) private var 关闭

    @State private var tag: String = ""
    @State private var url: String = ""
    @State private var download_detour: String = "direct"
    @State private var update_interval: String = "1d"

    var body: some View {
        NavigationStack {
            Form {
                AppFormRow(标签: "标签名") {
                    TextField("geoip", text: $tag)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                AppFormRow(标签: "格式") {
                    Text("binary")
                        .foregroundColor(.secondary)
                }
                AppFormRow(标签: "下载 URL") {
                    TextField("https://...", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }
                AppFormRow(标签: "下载出口") {
                    Picker("", selection: $download_detour) {
                        Text("direct").tag("direct")
                        Text("proxy").tag("proxy")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                AppFormRow(标签: "更新间隔") {
                    Picker("", selection: $update_interval) {
                        Text("1天").tag("1d")
                        Text("7天").tag("7d")
                        Text("30天").tag("30d")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .navigationTitle(编辑中的配置 == nil ? "添加规则集" : "编辑规则集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        保存()
                    }
                    .disabled(tag.isEmpty || url.isEmpty)
                }
            }
            .onAppear {
                if let 现有 = 编辑中的配置 {
                    tag = 现有.tag
                    url = 现有.url
                    download_detour = 现有.download_detour
                    update_interval = 现有.update_interval
                }
            }
        }
    }

    private func 保存() {
        if var 现有 = 编辑中的配置 {
            现有.tag = tag
            现有.url = url
            现有.download_detour = download_detour
            现有.update_interval = update_interval
            现有.本地文件名 = "\(tag).srs"
            管理器.更新规则集(现有)
        } else {
            let 新配置 = 规则集配置(
                tag: tag,
                url: url,
                download_detour: download_detour,
                update_interval: update_interval
            )
            管理器.添加规则集(新配置)
        }
        关闭()
    }
}
