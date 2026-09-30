//
//  组件/底部弹窗容器.swift
//  sing-box-for-apple 新UI
//
//  底部90%+高度弹窗容器
//  左上角向下箭头点击关闭，支持下滑手势关闭
//  弹窗内容由各业务页面后续任务填充，本文件仅提供占位视图
//

import SwiftUI

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

// MARK: - 各弹窗占位内容

/// 根据弹窗类型返回对应内容视图（占位实现，后续任务替换为正式业务页面）
private struct 弹窗内容视图: View {
    /// 弹窗类型
    let 类型: 底部弹窗类型

    var body: some View {
        switch 类型 {
        case .配置:
            配置管理占位视图()
        case .工具:
            工具占位视图()
        case .设置:
            设置占位视图()
        case .关于:
            关于占位视图()
        }
    }
}

// MARK: - 配置管理占位

/// 配置管理占位视图
private struct 配置管理占位视图: View {
    var body: some View {
        List {
            Section("配置文件") {
                占位行(图标: "square.stack.3d.up", 标题: "配置文件列表", 说明: "由后续任务接入官方 ProfileManager")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 工具占位

/// 工具占位视图
private struct 工具占位视图: View {
    var body: some View {
        List {
            Section("网络工具") {
                占位行(图标: "wrench.and.screwdriver", 标题: "工具集", 说明: "由后续任务接入 ping / 延迟测试等")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 设置占位

/// 设置占位视图
private struct 设置占位视图: View {
    var body: some View {
        List {
            Section("通用") {
                占位行(图标: "paintpalette", 标题: "外观主题", 说明: "浅色 / 深色 / 跟随系统")
                占位行(图标: "globe", 标题: "语言", 说明: "跟随系统")
                占位行(图标: "power", 标题: "启动时自动连接", 说明: "待接入")
            }
            Section("网络") {
                占位行(图标: "arrow.left.arrow.right", 标题: "运行模式", 说明: "由后续任务接入官方运行模式")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 关于占位

/// 关于占位视图
private struct 关于占位视图: View {
    var body: some View {
        List {
            Section("关于") {
                HStack {
                    Label("版本信息", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "--")
                        .foregroundColor(.次要文字)
                }
                HStack {
                    Label("开源仓库", systemImage: "star")
                    Spacer()
                    Text(全局常量.仓库地址)
                        .font(.system(size: 12))
                        .foregroundColor(.次要文字)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 占位行

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
