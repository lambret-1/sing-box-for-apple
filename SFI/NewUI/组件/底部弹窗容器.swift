//
//  组件/底部弹窗容器.swift
//  sing-box-for-apple 新UI
//
//  底部90%+高度弹窗容器
//  左上角向下箭头点击关闭，支持下滑手势关闭
//  四个弹窗：配置管理（官方 ProfileManager）/ 工具（官方 ToolsView）/ 设置（官方 SettingView）/ 关于
//

import SwiftUI
import ApplicationLibrary
import Library

// MARK: - 底部弹窗容器修饰符

/// 底部弹窗容器修饰符
struct 底部弹窗容器: ViewModifier {
    /// 绑定弹窗类型（nil 表示关闭）
    @Binding var 弹窗类型: 底部弹窗类型?

    func body(content: Content) -> some View {
        content
            .sheet(item: $弹窗类型) { 类型 in
                底部弹窗内容(弹窗类型: 类型) {
                    弹窗类型 = nil
                }
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.95)])
                .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - 弹窗内容

/// 底部弹窗内容视图：统一导航栏 + 左上角关闭按钮
///
/// 官方 ToolsView / SettingView 内部为 Form + NavigationLink，不自带 NavigationStack，
/// 因此这里统一在外层包一个 NavigationStack，保证导航链接可正常 push。
private struct 底部弹窗内容: View {
    /// 弹窗类型
    let 弹窗类型: 底部弹窗类型
    /// 关闭回调
    let 关闭: () -> Void

    var body: some View {
        NavigationStack {
            弹窗内容视图(类型: 弹窗类型)
                .navigationTitle(弹窗类型.标题)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            关闭()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }
}

// MARK: - 各弹窗内容

/// 根据弹窗类型返回对应内容视图
private struct 弹窗内容视图: View {
    /// 弹窗类型
    let 类型: 底部弹窗类型

    var body: some View {
        switch 类型 {
        case .配置:
            配置管理视图()
        case .工具:
            ToolsView()
        case .设置:
            SettingView()
        case .关于:
            关于视图()
        }
    }
}

// MARK: - 配置管理

/// 配置管理视图：从官方 ProfileManager 读取配置列表，点击切换当前配置
@MainActor
private struct 配置管理视图: View {
    /// 官方扩展环境（切换配置时调用 selectedProfileUpdate / reloadService）
    @EnvironmentObject private var 环境: ExtensionEnvironments

    /// 配置列表（官方 ProfilePreview 快照）
    @State private var 配置列表: [ProfilePreview] = []
    /// 当前选中的配置 ID
    @State private var 当前选中: Int64 = -1
    /// 是否正在加载
    @State private var 加载中 = true
    /// 提示文案（错误 / 占位提示）
    @State private var 提示: String?

    var body: some View {
        Group {
            if 加载中 {
                ProgressView()
                    .controlSize(.large)
            } else if 配置列表.isEmpty {
                EmptyStateView(图标: "square.stack.3d.up",
                               标题: "暂无配置",
                               说明: "点击右上角添加配置文件")
            } else {
                List {
                    Section {
                        ForEach(配置列表) { 配置 in
                            Button {
                                切换配置(配置.id)
                            } label: {
                                HStack(spacing: 间距常量.中等) {
                                    Image(systemName: 配置.类型图标)
                                        .foregroundColor(.主题色)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(配置.name)
                                            .font(字体层级.正文)
                                            .foregroundColor(.primary)
                                        Text(配置.类型说明)
                                            .font(字体层级.辅助说明)
                                            .foregroundColor(.次要文字)
                                    }
                                    Spacer()
                                    if 配置.id == 当前选中 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.主题色)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    提示 = "后续阶段支持"
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加配置")
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
        .task {
            await 加载配置()
        }
    }

    /// 从官方 ProfileManager 加载配置列表
    private func 加载配置() async {
        do {
            let 列表 = try await ProfileManager.list()
            配置列表 = 列表.map { ProfilePreview($0) }
            当前选中 = await SharedPreferences.selectedProfileID.get()
            // 若当前选中不在列表中，自动选中第一项并持久化
            if !配置列表.contains(where: { $0.id == 当前选中 }), let 首个 = 配置列表.first {
                当前选中 = 首个.id
                await SharedPreferences.selectedProfileID.set(当前选中)
            }
        } catch {
            提示 = "加载配置失败：\(error.localizedDescription)"
        }
        加载中 = false
    }

    /// 切换当前配置：写偏好 → 通知环境 → 已连接则重载服务
    private func 切换配置(_ id: Int64) {
        guard id != 当前选中 else { return }
        Task { @MainActor in
            await SharedPreferences.selectedProfileID.set(id)
            环境.selectedProfileUpdate.send()
            当前选中 = id
            if let profile = 环境.extensionProfile, profile.status == .connected {
                do {
                    try await profile.reloadService()
                } catch {
                    提示 = "重载服务失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

/// ProfilePreview 类型说明与图标辅助
private extension ProfilePreview {
    /// 中文类型说明
    var 类型说明: String {
        switch type {
        case .local: return "本地配置"
        case .icloud: return "iCloud 同步"
        case .remote: return "远程订阅"
        }
    }

    /// 对应 SF Symbols 图标
    var 类型图标: String {
        switch type {
        case .local: return "folder"
        case .icloud: return "icloud"
        case .remote: return "arrow.down.circle"
        }
    }
}

// MARK: - 关于

/// 关于视图：应用图标、版本号、构建号、开源仓库、Libbox 版本
private struct 关于视图: View {
    /// 版本号（CFBundleShortVersionString）
    private var 版本号: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "--"
    }

    /// 构建号（CFBundleVersion）
    private var 构建号: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 间距常量.中等) {
                    Image(systemName: "network")
                        .font(.system(size: 56))
                        .foregroundColor(.主题色)
                    Text("sing-box")
                        .font(字体层级.卡片标题)
                    Text("版本 \(版本号) (\(构建号))")
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("信息") {
                关于行(图标: "info.circle", 标题: "版本号", 右侧: 版本号)
                关于行(图标: "number", 标题: "构建号", 右侧: 构建号)
                关于行(图标: "shippingbox", 标题: "Libbox", 右侧: "内置")
            }

            Section("链接") {
                Link(destination: URL(string: 全局常量.仓库地址)!) {
                    Label("开源仓库", systemImage: "star")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.次要文字)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

/// 关于页信息行：图标 + 标题 + 右侧值
private struct 关于行: View {
    let 图标: String
    let 标题: String
    let 右侧: String

    var body: some View {
        HStack(spacing: 间距常量.中等) {
            Image(systemName: 图标)
                .foregroundColor(.主题色)
                .frame(width: 24)
            Text(标题)
                .font(字体层级.正文)
            Spacer()
            Text(右侧)
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
        }
    }
}

// MARK: - 占位行（运行模式面板使用）

/// 占位列表行组件
private struct 占位行: View {
    /// SF Symbols 图标
    let 图标: String
    /// 标题
    let 标题: String
    /// 右侧说明
    let 说明: String

    var body: some View {
        HStack(spacing: 间距常量.中等) {
            Image(systemName: 图标)
                .foregroundColor(.主题色)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(标题)
                    .font(字体层级.正文)
                Text(说明)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
            }
            Spacer()
        }
        .padding(.vertical, 间距常量.紧凑 / 2)
    }
}

// MARK: - 扩展

extension View {
    /// 添加底部弹窗容器
    func 底部弹窗(弹窗类型: Binding<底部弹窗类型?>) -> some View {
        modifier(底部弹窗容器(弹窗类型: 弹窗类型))
    }

    /// 运行模式选择面板（占位实现，后续阶段接入官方运行模式切换）
    func 运行模式面板(显示: Binding<Bool>) -> some View {
        modifier(运行模式面板修饰符(显示: 显示))
    }
}

// MARK: - 运行模式面板修饰符

/// 运行模式选择面板修饰符（骨架阶段占位）
private struct 运行模式面板修饰符: ViewModifier {
    /// 是否显示
    @Binding var 显示: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $显示) {
                运行模式面板内容()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
}

/// 运行模式面板内容（占位）
private struct 运行模式面板内容: View {
    var body: some View {
        NavigationStack {
            List {
                Section("运行模式") {
                    占位行(图标: "network", 标题: "规则模式", 说明: "按分流规则路由")
                    占位行(图标: "globe", 标题: "全局模式", 说明: "全部流量走代理")
                    占位行(图标: "arrow.uturn.forward", 标题: "直连模式", 说明: "不经过代理")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("运行模式")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 预览

#Preview {
    文本预览()
        .environmentObject(新UI状态())
}

/// 预览辅助：展示弹窗容器
private struct 文本预览: View {
    @State private var 类型: 底部弹窗类型? = .设置

    var body: some View {
        Button("打开弹窗") { 类型 = .设置 }
            .底部弹窗(弹窗类型: $类型)
    }
}
