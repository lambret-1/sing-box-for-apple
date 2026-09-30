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
    /// 新UI全局状态
    @EnvironmentObject private var 状态: 新UI状态

    var body: some View {
        switch 类型 {
        case .配置:
            ProfilePickerSheet(
                profileList: $状态.配置列表,
                selectedProfileID: $状态.当前选中配置
            )
            .onAppear {
                Task { await 状态.加载配置列表() }
            }
        case .工具:
            ToolsView()
        case .设置:
            设置与功能页面视图()
        case .关于:
            关于视图()
        }
    }
}

// MARK: - 设置 + 功能页面组合视图

/// 设置弹窗：官方 SettingView + 底部功能页面入口
private struct 设置与功能页面视图: View {
    var body: some View {
        VStack(spacing: 0) {
            SettingView()
                .layoutPriority(1)

            // 功能页面入口区域
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("功能页面")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.次要文字)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                }
                HStack(spacing: 0) {
                    功能导航项(图标: "network", 标题: "DNS", 目标: DNS设置页面())
                    功能导航项(图标: "lock.slash", 标题: "MITM", 目标: MITM设置页面())
                    功能导航项(图标: "waveform.badge.magnifyingglass", 标题: "抓包", 目标: 抓包列表页面())
                    功能导航项(图标: "pencil.and.ellipsis.rectangle", 标题: "重写", 目标: 重写规则设置页面())
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color.页面背景)
        }
    }
}

/// 功能页面导航项（图标 + 标题，NavigationLink）
private struct 功能导航项<目标: View>: View {
    let 图标: String
    let 标题: String
    let 目标: 目标

    var body: some View {
        NavigationLink {
            目标
        } label: {
            VStack(spacing: 4) {
                Image(systemName: 图标)
                    .font(.system(size: 18))
                    .foregroundColor(.主题色)
                    .frame(width: 36, height: 36)
                    .background(Color.主题色.opacity(0.12))
                    .cornerRadius(10)
                Text(标题)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - 关于行（弹窗内使用）

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
