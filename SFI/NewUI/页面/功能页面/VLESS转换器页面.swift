//
//  页面/功能页面/VLESS转换器页面.swift
//  sing-box-for-apple 新UI
//
//  VLESS 转换器主页面：输入 → 转换 → 结果列表 → 筛选/搜索 → 详情编辑 → 导出/导入
//  以 fullScreenCover 独立全屏打开
//

import SwiftUI
import UniformTypeIdentifiers

/// VLESS 转换器主页面
struct VLESS转换器页面: View {
    /// 转换器状态
    @StateObject private var 状态 = VLESS转换器状态()
    /// 环境关闭回调
    @Environment(\.dismiss) private var 关闭

    // MARK: 界面状态
    @State private var 显示历史表: Bool = false
    @State private var 显示设置表: Bool = false
    @State private var 显示导入确认: Bool = false
    @State private var 导入结果提示: String?
    @State private var 显示导入结果: Bool = false
    @State private var 文件导入结果: String?
    @State private var 显示文件导入提示: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 间距常量.中等) {
                    输入区
                    转换操作区
                    if !状态.解析结果列表.isEmpty {
                        筛选搜索区
                        统计行
                        结果列表
                    } else {
                        空态占位
                    }
                }
                .padding(.horizontal, 间距常量.标准)
                .padding(.vertical, 间距常量.中等)
            }
            .background(Color.页面背景.ignoresSafeArea())
            .navigationTitle("VLESS 转换器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { 关闭() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { 显示历史表 = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Button { 显示设置表 = true } label: {
                        Image(systemName: "gearshape")
                    }
                    if !状态.解析结果列表.isEmpty {
                        Menu {
                            Button("全选") { 状态.全选() }
                            Button("反选") { 状态.反选() }
                            Button("取消全选", role: .cancel) { 状态.取消全选() }
                            Divider()
                            Button("删除失败节点", role: .destructive) { 状态.删除失败节点() }
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                底部工具栏
            }
            .sheet(isPresented: $显示历史表) { 历史表 }
            .sheet(isPresented: $显示设置表) { 设置表 }
            .fileImporter(isPresented: .constant(显示文件选择), allowedContentTypes: [.plainText, .json]) { 结果 in
                处理文件导入(结果)
            }
            .alert("导入节点库", isPresented: $显示导入确认) {
                Button("取消", role: .cancel) {}
                Button("导入") {
                    Task {
                        let 结果 = await 状态.导入节点库()
                        导入结果提示 = "新增 \(结果.新增) 个 · 跳过 \(结果.跳过) 个重复"
                        显示导入结果 = true
                    }
                }
            } message: {
                Text("将导入 \(状态.去重后的节点列表.count) 个去重后的节点，创建为本地配置文件。")
            }
            .alert("导入结果", isPresented: $显示导入结果) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(导入结果提示 ?? "")
            }
            .alert("文件导入", isPresented: $显示文件导入提示) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(文件导入提示 ?? "")
            }
        }
    }

    // 文件选择绑定（用 @State 控制）
    @State private var 显示文件选择: Bool = false

    // MARK: Section 1 输入区

    private var 输入区: some View {
        AppCard(标题: "输入 VLESS 链接") {
            VStack(alignment: .leading, spacing: 间距常量.中等) {
                TextEditor(text: $状态.输入文本)
                    .font(字体层级.正文)
                    .frame(minHeight: 120)
                    .padding(间距常量.紧凑)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 圆角常量.标准))

                HStack(spacing: 间距常量.中等) {
                    Button { 状态.从剪贴板粘贴() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("粘贴")
                        }
                        .font(字体层级.正文)
                        .foregroundColor(.主题色)
                    }
                    Button { 状态.清空输入() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清空")
                        }
                        .font(字体层级.正文)
                        .foregroundColor(.危险色)
                    }
                    Spacer()
                    Text("已输入 \(状态.已输入行数) 行")
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
            }
        }
    }

    // MARK: Section 2 转换按钮

    private var 转换操作区: some View {
        VStack(spacing: 间距常量.紧凑) {
            AppButton("开始转换", 样式: .主要, 全宽: true) {
                状态.执行转换()
            }
            .disabled(状态.输入文本.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if 状态.转换中 {
                ProgressView(value: 状态.转换进度)
                    .progressViewStyle(.linear)
                    .tint(.主题色)
            }
        }
    }

    // MARK: Section 3 筛选搜索

    private var 筛选搜索区: some View {
        VStack(spacing: 间距常量.紧凑) {
            AppSearchBar(搜索文字: $状态.搜索文本, 占位文字: "搜索节点名称或服务器")

            HStack(spacing: 间距常量.紧凑) {
                ForEach(VLESS筛选状态.allCases, id: \.self) { 筛选项 in
                    let 数量 = 数量对于筛选(筛选项)
                    Button {
                        withAnimation(.easeInOut(duration: 动画常量.快速)) {
                            状态.筛选状态 = 筛选项
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(筛选项.显示文字)
                            Text("\(数量)")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .font(字体层级.正文)
                        .foregroundColor(.white)
                        .padding(.horizontal, 间距常量.中等)
                        .padding(.vertical, 间距常量.紧凑)
                        .background(状态.筛选状态 == 筛选项 ? Color.主题色 : Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: 统计行

    private var 统计行: some View {
        HStack {
            Text("共 \(状态.解析结果列表.count) 个 · 成功 \(状态.成功数) · 失败 \(状态.失败数)")
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
            Spacer()
            if !状态.选中集合.isEmpty {
                Text("已选 \(状态.选中集合.count)")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.主题色)
            }
        }
    }

    // MARK: Section 4 结果列表

    private var 结果列表: some View {
        VStack(spacing: 间距常量.中等) {
            if 状态.筛选后的列表.isEmpty {
                Text("无匹配结果")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                    .padding(.vertical, 间距常量.宽松)
            } else {
                ForEach(状态.筛选后的列表) { 项 in
                    VLESS节点卡片(
                        状态: 状态,
                        项: 项,
                        展开: Binding(
                            get: { 状态.显示详情 == 项.id },
                            set: { 新值 in
                                状态.显示详情 = 新值 ? 项.id : nil
                            }
                        )
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            状态.删除节点(项.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: 空态

    private var 空态占位: some View {
        EmptyStateView(
            图标: "arrow.triangle.2.circlepath",
            标题: "粘贴 VLESS 链接后点击转换",
            说明: "支持批量粘贴多行 vless:// 链接，自动解析为 sing-box JSON"
        )
    }

    // MARK: 底部工具栏

    private var 底部工具栏: some View {
        HStack(spacing: 间距常量.紧凑) {
            // 导出选中
            Button {
                let json = 状态.生成导出JSON(仅选中: true)
                状态.复制到剪贴板(json)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up.on.square")
                    Text("导出选中")
                }
                .font(字体层级.辅助说明)
                .foregroundColor(状态.选中集合.isEmpty ? .次要文字 : .主题色)
            }
            .disabled(状态.选中集合.isEmpty)

            // 导出全部
            Button {
                let json = 状态.生成导出JSON(仅选中: false)
                状态.复制到剪贴板(json)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出全部")
                }
                .font(字体层级.辅助说明)
                .foregroundColor(状态.成功数 == 0 ? .次要文字 : .主题色)
            }
            .disabled(状态.成功数 == 0)

            Spacer()

            // 导入文件
            Button {
                显示文件选择 = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                    Text("导入文件")
                }
                .font(字体层级.辅助说明)
                .foregroundColor(.主题色)
            }

            // 导入节点库
            Button {
                显示导入确认 = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                    Text("导入节点库")
                }
                .font(字体层级.辅助说明)
                .foregroundColor(状态.成功数 == 0 ? .次要文字 : .主题色)
            }
            .disabled(状态.成功数 == 0)
        }
        .padding(.horizontal, 间距常量.标准)
        .padding(.vertical, 间距常量.紧凑)
        .background(.ultraThinMaterial)
    }

    // MARK: 历史 sheet

    private var 历史表: some View {
        NavigationStack {
            List {
                if 状态.转换历史列表.isEmpty {
                    Text("暂无转换历史")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(状态.转换历史列表) { 记录 in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(记录.时间.formatted(date: .abbreviated, time: .shortened))
                                .font(字体层级.正文)
                            Text("输入 \(记录.输入行数) 行 · 成功 \(记录.成功数) · 失败 \(记录.失败数)")
                                .font(字体层级.辅助说明)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("转换历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { 显示历史表 = false }
                }
            }
        }
    }

    // MARK: 设置 sheet

    private var 设置表: some View {
        NavigationStack {
            Form {
                AppFormRow(标签: "默认 uTLS 指纹") {
                    Picker("", selection: $状态.默认uTLS指纹) {
                        Text("chrome").tag("chrome")
                        Text("firefox").tag("firefox")
                        Text("safari").tag("safari")
                        Text("ios").tag("ios")
                        Text("android").tag("android")
                        Text("edge").tag("edge")
                        Text("random").tag("random")
                        Text("randomized").tag("randomized")
                    }
                    .labelsHidden()
                }
                AppFormRow(标签: "TLS 不安全") {
                    Toggle("", isOn: $状态.默认TLS不安全)
                        .labelsHidden()
                }
                AppFormRow(标签: "默认 packet_encoding") {
                    Picker("", selection: $状态.默认packet编码) {
                        Text("关闭").tag("")
                        Text("xudp").tag("xudp")
                    }
                    .labelsHidden()
                }
            }
            .navigationTitle("转换器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { 显示设置表 = false }
                }
            }
        }
    }

    // MARK: 文件导入处理

    private func 处理文件导入(_ 结果: Result<URL, Error>) {
        switch 结果 {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                文件导入提示 = "无法访问文件"
                显示文件导入提示 = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let 内容 = try String(contentsOf: url, encoding: .utf8)
                if url.pathExtension == "json" {
                    let 数 = 状态.导入JSON文件(内容)
                    文件导入提示 = "已从 JSON 导入 \(数) 个 vless 节点"
                } else {
                    let 旧数 = 状态.解析结果列表.count
                    状态.导入文本文件(内容)
                    let 新增数 = 状态.解析结果列表.count - 旧数
                    文件导入提示 = "已从文本文件导入 \(新增数) 行"
                }
                显示文件导入提示 = true
            } catch {
                文件导入提示 = "读取文件失败: \(error.localizedDescription)"
                显示文件导入提示 = true
            }
        case .failure(let error):
            文件导入提示 = "选择文件失败: \(error.localizedDescription)"
            显示文件导入提示 = true
        }
    }

    // MARK: 辅助

    private func 数量对于筛选(_ 筛选: VLESS筛选状态) -> Int {
        switch 筛选 {
        case .全部: return 状态.解析结果列表.count
        case .成功: return 状态.成功数
        case .失败: return 状态.失败数
        }
    }
}

// MARK: - 预览

#Preview {
    VLESS转换器页面()
}
