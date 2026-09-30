//
//  页面/仪表盘视图.swift
//  sing-box-for-apple 新UI
//
//  仪表盘主页面
//  布局：顶部状态区 + 顶部功能卡片栏 + 内容区（ScrollView）+ 底部工具栏
//  数据层对接官方 ExtensionProfile，通过 新UI状态 桥接
//

import SwiftUI
import Combine
import Libbox
import ApplicationLibrary
import Library

/// 仪表盘主页面视图
struct 仪表盘视图: View {
    /// 新UI全局状态
    @EnvironmentObject private var 状态: 新UI状态
    /// 官方扩展环境（供 ProfileCard 使用）
    @EnvironmentObject private var 环境: ExtensionEnvironments
    /// 是否显示 VLESS 转换器全屏页
    @State private var 显示VLESS转换器 = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态区（固定，不随内容滚动）
            顶部状态区()
                .padding(.horizontal, 间距常量.标准)
                .padding(.top, 间距常量.紧凑)

            // 横向功能卡片栏（固定）
            顶部功能卡片栏()

            // 工具入口条：VLESS 转换器
            工具入口条
                .padding(.horizontal, 间距常量.标准)
                .padding(.bottom, 间距常量.紧凑)

            // 内容区：占满剩余高度
            // 日志页不使用 ScrollView，让官方 LogView 占满剩余空间延伸到底部
            if 状态.当前顶部卡片 == .规则与日志 {
                规则与日志内容区()
                    .environmentObject(环境)
            } else {
                ScrollView {
                    VStack(spacing: 间距常量.中等) {
                        // 官方配置卡片（仅节点页显示）
                        if 状态.当前顶部卡片 == .节点 {
                            ProfileCard(
                                profileList: $状态.配置列表,
                                selectedProfileID: $状态.当前选中配置
                            )
                            .environmentObject(环境)
                        }

                        主内容区()
                            .padding(.bottom, 间距常量.标准)
                    }
                    .padding(.horizontal, 间距常量.标准)
                }
            }

            // 底部固定工具栏
            底部工具栏()
        }
        .environmentObject(环境.commandClient)
        .background(Color.页面背景.ignoresSafeArea())
        .底部弹窗(弹窗类型: $状态.当前底部弹窗)
        .运行模式面板(显示: $状态.显示运行模式面板)
        .错误提示(信息: 状态.错误信息)
        .fullScreenCover(isPresented: $显示VLESS转换器) {
            VLESS转换器页面()
        }
        .onAppear {
            // 加载配置列表
            Task { await 状态.加载配置列表() }
        }
    }
}

// MARK: - 工具入口条

extension 仪表盘视图 {
    /// 工具入口条：一排小工具按钮，目前包含 VLESS 转换器
    var 工具入口条: some View {
        HStack(spacing: 间距常量.紧凑) {
            工具入口按钮(
                图标: "arrow.triangle.2.circlepath",
                标题: "VLESS 转换",
                副标题: "链接转 JSON"
            ) {
                显示VLESS转换器 = true
            }
            Spacer()
        }
    }
}

/// 单个工具入口按钮
private struct 工具入口按钮: View {
    let 图标: String
    let 标题: String
    let 副标题: String
    let 动作: () -> Void

    var body: some View {
        Button(action: 动作) {
            HStack(spacing: 间距常量.紧凑) {
                Image(systemName: 图标)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.主题色)
                VStack(alignment: .leading, spacing: 1) {
                    Text(标题)
                        .font(字体层级.正文)
                        .foregroundColor(.primary)
                    Text(副标题)
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.次要文字)
            }
            .padding(.horizontal, 间距常量.中等)
            .padding(.vertical, 间距常量.紧凑)
            .background(Color.卡片背景)
            .clipShape(RoundedRectangle(cornerRadius: 圆角常量.标准))
            .overlay(
                RoundedRectangle(cornerRadius: 圆角常量.标准)
                    .stroke(Color.分割线, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 顶部状态区

/// 顶部状态区：左侧 VPN 状态文字 + 连接时长 + 实时流量，右侧电源开关
private struct 顶部状态区: View {
    /// 新UI全局状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 每秒节拍：驱动连接时长与流量刷新
    private let 计时器 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 实时流量快照（每秒从 CommandClient 读取）
    @State private var 流量: LibboxStatusMessage?

    var body: some View {
        HStack(alignment: .top) {
            // 左侧：状态文字 + 连接时长 + 实时流量
            VStack(alignment: .leading, spacing: 间距常量.紧凑) {
                Text(状态.当前VPN状态.显示文字)
                    .font(字体层级.大标题)
                    .foregroundColor(状态.当前VPN状态.颜色)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.次要文字)
                    Text(状态.是否已连接 ? 状态.连接时长 : "--:--:--")
                        .font(字体层级.辅助说明)
                        .foregroundColor(状态.是否已连接 ? .次要文字 : .clear)
                        .monospacedDigit()
                }

                // 实时上下行流量速率（仅已连接时显示）
                if 状态.是否已连接, let 流量 {
                    HStack(spacing: 间距常量.中等) {
                        // 下行
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.成功色)
                            Text(LibboxFormatBytes(流量.downlink) + "/s")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.次要文字)
                                .monospacedDigit()
                        }
                        // 上行
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.主题色)
                            Text(LibboxFormatBytes(流量.uplink) + "/s")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.次要文字)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Spacer()

            // 右侧：电源开关（调用官方 ExtensionProfile start/stop）
            Toggle("", isOn: Binding(
                get: { 状态.当前VPN状态.是否活动 },
                set: { _ in
                    状态.切换连接()
                }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .成功色))
            .disabled(状态.操作中 || 状态.当前VPN状态 == .无效)
            .padding(.top, 4)
        }
        .frame(minHeight: 56)
        // 每秒刷新连接时长与实时流量
        .onReceive(计时器) { _ in
            流量 = 状态.命令客户端?.status
        }
    }
}

// MARK: - 主内容区

/// 根据选中顶部卡片切换内容区（占位视图，后续任务在 页面/内容区/ 下实现）
private struct 主内容区: View {
    /// 新UI全局状态
    @EnvironmentObject private var 状态: 新UI状态

    var body: some View {
        Group {
            switch 状态.当前顶部卡片 {
            case .节点:
                节点内容区()
            case .策略组:
                策略组内容区()
            case .网络活动:
                网络活动内容区()
            case .规则与日志:
                规则与日志内容区()
            }
        }
        .animation(.easeInOut(duration: 动画常量.快速), value: 状态.当前顶部卡片)
    }
}

// MARK: - 错误提示修饰符

extension View {
    /// 操作错误提示（错误信息非空时弹 alert）
    func 错误提示(信息: String?) -> some View {
        modifier(错误提示修饰符(错误信息: 信息))
    }
}

/// 错误提示修饰符
private struct 错误提示修饰符: ViewModifier {
    /// 错误信息
    let 错误信息: String?
    /// 是否展示 alert
    @State private var 展示错误: Bool = false

    func body(content: Content) -> some View {
        content
            .onChange(of: 错误信息) { 新值 in
                展示错误 = (新值 != nil)
            }
            .alert("操作失败", isPresented: $展示错误) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(错误信息 ?? "")
            }
    }
}

// MARK: - 预览

#Preview {
    仪表盘视图()
        .environmentObject(新UI状态())
}
