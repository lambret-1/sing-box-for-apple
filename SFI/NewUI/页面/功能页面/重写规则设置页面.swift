//
//  页面/功能页面/重写规则设置页面.swift
//  sing-box-for-apple 新UI
//
//  URL 重写规则设置页面：规则列表、添加/编辑/删除、本地映射管理
//

import SwiftUI

// MARK: - 重写规则设置页面

/// URL 重写规则设置页面
struct 重写规则设置页面: View {
    @ObservedObject var mitm = MITM状态.共享

    /// 是否显示编辑器
    @State private var 显示编辑器 = false
    /// 当前编辑的规则
    @State private var 编辑中规则: 重写规则条目?
    /// 是否显示本地映射
    @State private var 显示本地映射 = false

    var body: some View {
        List {
            // MARK: 总开关
            Section {
                AppFormRow(标签: "启用重写功能", 说明: "对匹配的请求或响应执行自定义改写规则") {
                    Toggle("", isOn: .constant(mitm.启用MITM)).labelsHidden()
                }
            } footer: {
                Text("重写功能依赖 MITM 解密，请先在 MITM 设置中启用")
            }

            // MARK: 规则列表
            Section("重写规则") {
                if mitm.重写规则列表.isEmpty {
                    EmptyStateView(
                        图标: "arrow.triangle.turn.up.right.diamond",
                        标题: "暂无重写规则",
                        说明: "点击右上角 + 添加 URL 重写规则"
                    )
                } else {
                    ForEach(mitm.重写规则列表) { 规则 in
                        规则行(规则: 规则) {
                            编辑中规则 = 规则
                            显示编辑器 = true
                        }
                    }
                    .onDelete(perform: 删除规则)
                }
            }

            // MARK: 本地映射入口
            Section {
                NavigationLink {
                    本地映射页面()
                } label: {
                    HStack(spacing: 间距常量.中等) {
                        Image(systemName: "folder")
                            .foregroundColor(.主题色)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("本地映射")
                                .font(字体层级.正文)
                                .foregroundColor(.primary)
                            Text("远程 URL 映射到本地文件或文本")
                                .font(字体层级.辅助说明)
                                .foregroundColor(.次要文字)
                        }
                        Spacer()
                        StateBadge(文字: "\(mitm.本地映射列表.filter { $0.启用 }.count)", 类型: .信息, 带圆点: false)
                    }
                    .padding(.vertical, 间距常量.紧凑 / 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("重写规则")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    编辑中规则 = 重写规则条目(名称: "新规则", 匹配模式: "", 目标值: "")
                    显示编辑器 = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $显示编辑器) {
            if let 规则 = 编辑中规则 {
                重写规则编辑页面(规则: 规则) { 保存后的规则 in
                    保存规则(保存后的规则)
                    显示编辑器 = false
                }
            }
        }
    }

    // MARK: - 方法

    private func 保存规则(_ 规则: 重写规则条目) {
        if let 索引 = mitm.重写规则列表.firstIndex(where: { $0.id == 规则.id }) {
            mitm.重写规则列表[索引] = 规则
        } else {
            mitm.重写规则列表.append(规则)
        }
    }

    private func 删除规则(at offsets: IndexSet) {
        mitm.重写规则列表.remove(atOffsets: offsets)
    }
}

// MARK: - 规则行

/// 单条重写规则行
private struct 规则行: View {
    let 规则: 重写规则条目
    let 点击编辑: () -> Void

    var body: some View {
        Button {
            点击编辑()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(规则.名称)
                        .font(字体层级.正文)
                        .foregroundColor(.primary)
                    Spacer()
                    StateBadge(文字: 规则.类型.显示名称, 类型: .信息, 带圆点: false)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(规则.匹配模式)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.次要文字)
                        .lineLimit(1)
                    Text("→ \(规则.目标值)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.主题色)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 间距常量.紧凑 / 2)
        }
    }
}

// MARK: - 规则编辑页面

/// 重写规则编辑页面
struct 重写规则编辑页面: View {
    @State var 规则: 重写规则条目
    let 保存回调: (重写规则条目) -> Void

    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $规则.名称)

                    Picker("规则类型", selection: $规则.类型) {
                        ForEach(重写规则类型.allCases) { 类型 in
                            Text(类型.显示名称).tag(类型)
                        }
                    }
                }

                Section("匹配规则") {
                    TextField("匹配 URL 正则表达式", text: $规则.匹配模式)
                        .font(.system(.body, design: .monospaced))

                    TextField(规则.类型 == .拒绝 ? "拒绝原因（留空）" : "目标值",
                              text: $规则.目标值)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    Toggle("启用此规则", isOn: $规则.启用)
                }
            }
            .navigationTitle(规则.名称.isEmpty ? "新建规则" : 规则.名称)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        保存回调(规则)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 本地映射页面

/// 本地映射管理页面
struct 本地映射页面: View {
    @ObservedObject var mitm = MITM状态.共享
    @State private var 显示编辑器 = false
    @State private var 编辑中映射: 本地映射条目?

    var body: some View {
        List {
            Section {
                if mitm.本地映射列表.isEmpty {
                    EmptyStateView(
                        图标: "folder",
                        标题: "暂无本地映射",
                        说明: "将远程 URL 映射到本地文件或文本内容"
                    )
                } else {
                    ForEach(mitm.本地映射列表) { 项 in
                        本地映射行(项: 项) {
                            编辑中映射 = 项
                            显示编辑器 = true
                        }
                    }
                    .onDelete { 索引集 in
                        mitm.本地映射列表.remove(atOffsets: 索引集)
                    }
                }
            } footer: {
                Text("匹配的 URL 请求将直接返回本地内容，不发送到远程服务器")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("本地映射")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    编辑中映射 = 本地映射条目(名称: "新映射", 匹配模式: "")
                    显示编辑器 = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $显示编辑器) {
            if let 映射 = 编辑中映射 {
                本地映射编辑页面(映射: 映射) { 保存后的映射 in
                    保存映射(保存后的映射)
                    显示编辑器 = false
                }
            }
        }
    }

    private func 保存映射(_ 映射: 本地映射条目) {
        if let 索引 = mitm.本地映射列表.firstIndex(where: { $0.id == 映射.id }) {
            mitm.本地映射列表[索引] = 映射
        } else {
            mitm.本地映射列表.append(映射)
        }
    }
}

/// 本地映射行
private struct 本地映射行: View {
    let 项: 本地映射条目
    let 点击编辑: () -> Void

    var body: some View {
        Button {
            点击编辑()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(项.名称)
                        .font(字体层级.正文)
                        .foregroundColor(.primary)
                    Spacer()
                    StateBadge(文字: 项.映射类型.显示名称, 类型: .信息, 带圆点: false)
                }
                Text(项.匹配模式)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.次要文字)
                    .lineLimit(1)
                Text("状态码: \(项.状态码)")
                    .font(.system(size: 11))
                    .foregroundColor(.次要文字)
            }
            .padding(.vertical, 间距常量.紧凑 / 2)
        }
    }
}

/// 本地映射编辑页面
struct 本地映射编辑页面: View {
    @State var 映射: 本地映射条目
    let 保存回调: (本地映射条目) -> Void

    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("映射名称", text: $映射.名称)

                    Picker("映射类型", selection: $映射.映射类型) {
                        ForEach(本地映射条目.映射类型.allCases, id: \.self) { 类型 in
                            Text(类型.显示名称).tag(类型)
                        }
                    }
                }

                Section("匹配规则") {
                    TextField("匹配 URL 正则", text: $映射.匹配模式)
                        .font(.system(.body, design: .monospaced))
                }

                if 映射.映射类型 != .微缩GIF {
                    Section("数据内容") {
                        if 映射.映射类型 == .文本 {
                            TextEditor(text: $映射.数据内容)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 150)
                        } else {
                            TextField("数据路径或内容", text: $映射.数据内容)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                Section("响应设置") {
                    Stepper(value: $映射.状态码, in: 100...599) {
                        HStack {
                            Text("状态码")
                            Spacer()
                            Text("\(映射.状态码)")
                                .foregroundColor(.次要文字)
                        }
                    }
                }

                Section {
                    Toggle("启用此映射", isOn: $映射.启用)
                }
            }
            .navigationTitle(映射.名称.isEmpty ? "新建映射" : 映射.名称)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { 关闭() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        保存回调(映射)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        重写规则设置页面()
    }
}
