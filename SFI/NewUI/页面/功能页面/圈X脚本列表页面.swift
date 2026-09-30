//
//  页面/功能页面/圈X脚本列表页面.swift
//  sing-box-for-apple 新UI
//
//  圈 X 脚本列表页面：显示所有脚本、启用/禁用、编辑、删除、新建
//

import SwiftUI

struct 圈X脚本列表页面: View {
    @ObservedObject var mitm = MITM状态.共享
    @State private var 搜索文本 = ""
    @State private var 显示编辑器 = false
    @State private var 编辑中脚本: 圈X脚本条目?
    @State private var 显示预设库 = false

    private var 过滤后脚本: [圈X脚本条目] {
        if 搜索文本.isEmpty { return mitm.脚本列表 }
        return mitm.脚本列表.filter {
            $0.名称.localizedCaseInsensitiveContains(搜索文本) || $0.标签.localizedCaseInsensitiveContains(搜索文本)
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 间距常量.紧凑) {
                    Image(systemName: "magnifyingglass").foregroundColor(.次要文字)
                    TextField("搜索脚本", text: $搜索文本)
                }
            }

            Section("脚本列表") {
                if 过滤后脚本.isEmpty {
                    EmptyStateView(图标: "curlybraces", 标题: "暂无脚本", 说明: "点击右上角 + 创建新脚本")
                } else {
                    ForEach(过滤后脚本) { 脚本 in
                        脚本行(脚本: 脚本) { 编辑中脚本 = 脚本; 显示编辑器 = true }
                    }
                    .onDelete(perform: 删除脚本)
                }
            }

            Section {
                Button { 显示预设库 = true } label: {
                    Label("从预设库导入", systemImage: "square.grid.2x2")
                }
            } footer: {
                Text("圈 X 脚本使用 JavaScript 编写，兼容 Quantumult X 格式")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("圈 X 脚本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { 编辑中脚本 = 圈X脚本条目(名称: "新脚本"); 显示编辑器 = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $显示编辑器) {
            if let 脚本 = 编辑中脚本 {
                圈X脚本编辑页面(脚本: 脚本) { 保存后的 in 保存脚本(保存后的); 显示编辑器 = false }
            }
        }
        .sheet(isPresented: $显示预设库) {
            预设脚本库页面 { 选中 in mitm.脚本列表.append(选中); 显示预设库 = false }
        }
    }

    private func 保存脚本(_ 脚本: 圈X脚本条目) {
        if let 索引 = mitm.脚本列表.firstIndex(where: { $0.id == 脚本.id }) {
            mitm.脚本列表[索引] = 脚本
        } else {
            mitm.脚本列表.append(脚本)
        }
    }

    private func 删除脚本(at offsets: IndexSet) {
        mitm.脚本列表.remove(atOffsets: offsets)
    }
}

private struct 脚本行: View {
    let 脚本: 圈X脚本条目
    let 点击编辑: () -> Void
    var body: some View {
        Button { 点击编辑() } label: {
            HStack(spacing: 间距常量.中等) {
                Image(systemName: 脚本.类型 == .请求前 ? "arrow.down.circle" : "arrow.up.circle")
                    .foregroundColor(脚本.类型 == .请求前 ? .主题色 : .成功色)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(脚本.名称).font(字体层级.正文).foregroundColor(.primary)
                        if 脚本.需要请求体 { StateBadge(文字: "Body", 类型: .信息, 带圆点: false) }
                    }
                    Text(脚本.匹配模式).font(字体层级.辅助说明).foregroundColor(.次要文字).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StateBadge(文字: 脚本.类型 == .请求前 ? "请求前" : "响应前",
                               类型: 脚本.类型 == .请求前 ? .信息 : .成功, 带圆点: false)
                    Text(脚本.标签).font(.system(size: 10, design: .monospaced)).foregroundColor(.次要文字)
                }
            }
            .padding(.vertical, 间距常量.紧凑 / 2)
        }
    }
}

struct 圈X脚本编辑页面: View {
    @State var 脚本: 圈X脚本条目
    let 保存回调: (圈X脚本条目) -> Void
    @Environment(\.dismiss) private var 关闭
    @State private var 测试日志: [String] = []
    @State private var 正在测试 = false
    @State private var 显示测试结果 = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("脚本名称", text: $脚本.名称)
                    TextField("标签（英文标识）", text: $脚本.标签).font(.system(.body, design: .monospaced))
                    Picker("脚本类型", selection: $脚本.类型) {
                        ForEach(圈X脚本类型.allCases) { 类型 in Text(类型.显示名称).tag(类型) }
                    }
                    TextField("匹配 URL 正则", text: $脚本.匹配模式).font(.system(.body, design: .monospaced))
                }
                Section("脚本代码") {
                    TextEditor(text: $脚本.代码)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(RoundedRectangle(cornerRadius: 圆角常量.小).stroke(.分割线, lineWidth: 1))
                }
                Section("高级选项") {
                    Toggle("需要请求/响应体", isOn: $脚本.需要请求体)
                    Stepper(value: $脚本.超时秒数, in: 1...60) {
                        HStack { Text("超时时间"); Spacer(); Text("\(Int(脚本.超时秒数)) 秒").foregroundColor(.次要文字) }
                    }
                    Toggle("启用脚本", isOn: $脚本.启用)
                }
                Section {
                    Button { Task { await 测试脚本() } } label: {
                        HStack {
                            if 正在测试 { ProgressView().progressViewStyle(.circular) }
                            Text(正在测试 ? "测试中..." : "测试运行")
                        }
                    }.disabled(正在测试)
                } footer: { Text("使用示例请求/响应测试脚本逻辑") }
                if 显示测试结果 {
                    Section("测试输出") {
                        ForEach(测试日志, id: \.self) { 行 in
                            Text(行).font(.system(.caption, design: .monospaced)).foregroundColor(.次要文字).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle(脚本.名称.isEmpty ? "新建脚本" : 脚本.名称)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { 关闭() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { 保存回调(脚本) }.fontWeight(.semibold) }
            }
        }
    }

    private func 测试脚本() async {
        正在测试 = true; 测试日志 = []; 显示测试结果 = true
        测试日志 = await 圈X脚本引擎.共享.测试运行脚本(脚本代码: 脚本.代码, 类型: 脚本.类型)
        正在测试 = false
    }
}

struct 预设脚本库页面: View {
    let 选择回调: (圈X脚本条目) -> Void
    @Environment(\.dismiss) private var 关闭
    var body: some View {
        NavigationStack {
            List {
                ForEach(预设脚本库.预设) { 脚本 in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(脚本.名称).font(字体层级.卡片标题)
                            Spacer()
                            StateBadge(文字: 脚本.类型.显示名称, 类型: .信息, 带圆点: false)
                        }
                        Text(脚本.匹配模式).font(.system(.caption, design: .monospaced)).foregroundColor(.次要文字)
                        Text(脚本.代码).font(.system(.caption2, design: .monospaced)).foregroundColor(.次要文字).lineLimit(5)
                    }
                    .padding(.vertical, 间距常量.紧凑)
                    .contentShape(Rectangle())
                    .onTapGesture { 选择回调(脚本) }
                }
            }
            .navigationTitle("预设脚本库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { 关闭() } } }
        }
    }
}

#Preview {
    NavigationStack { 圈X脚本列表页面() }
}
