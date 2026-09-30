//
//  组件/底部工具栏.swift
//  sing-box-for-apple 新UI
//
//  底部固定工具栏，4个功能入口（配置/工具/设置/关于）
//  点击图标从底部弹出90%高度弹窗
//  设置图标点击打开设置，重按弹出运行模式选择面板
//  数据来源：新UI状态.当前底部弹窗 / 显示运行模式面板 / 当前VPN状态
//

import SwiftUI

/// 底部固定工具栏
struct 底部工具栏: View {
    /// 新UI全局状态
    @EnvironmentObject private var 状态: 新UI状态

    /// 工具栏高度
    private let 工具栏高度: CGFloat = 56
    /// 图标大小
    private let 图标大小: CGFloat = 22
    /// 左右边距
    private let 左右边距: CGFloat = 20
    /// 重按最短持续时间（秒）
    /// 图标旋转角度（连接状态下持续旋转）
    @State private var 旋转角度: Double = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(底部弹窗类型.allCases) { 弹窗类型 in
                Spacer()

                if 弹窗类型 == .设置 {
                    // 设置按钮：SF Symbols 图标，VPN连接时顺时针旋转，
                    // 点击打开设置弹窗，重按弹出运行模式选择面板
                    设置按钮(弹窗类型: 弹窗类型)
                } else {
                    // 普通按钮：点击打开对应弹窗
                    Button {
                        状态.当前底部弹窗 = 弹窗类型
                    } label: {
                        Image(systemName: 弹窗类型.图标)
                            .font(.system(size: 图标大小, weight: .regular))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
        }
        .padding(.horizontal, 左右边距)
        .frame(height: 工具栏高度)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            // 顶部分割线
            Rectangle()
                .fill(Color.分割线)
                .frame(height: 0.5)
        }
        .onAppear {
            启动旋转动画()
        }
        .onChange(of: 状态.当前VPN状态.是否活动) { _ in
            启动旋转动画()
        }
    }

    /// 根据 VPN 连接状态启动或停止旋转动画
    private func 启动旋转动画() {
        if 状态.当前VPN状态.是否活动 {
            // VPN 连接中：持续顺时针旋转，8秒一圈，无限循环
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                旋转角度 = 360
            }
        } else {
            // VPN 未连接：停止旋转，回到初始角度
            withAnimation(.easeOut(duration: 动画常量.标准)) {
                旋转角度 = 0
            }
        }
    }

    /// 设置按钮（点击打开设置弹窗，长按弹出 ContextMenu 选择运行模式）
    private func 设置按钮(弹窗类型: 底部弹窗类型) -> some View {
        Image(systemName: 弹窗类型.图标)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.primary)
            .rotationEffect(.degrees(旋转角度))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                状态.当前底部弹窗 = 弹窗类型
            }
            .contextMenu {
                Button {
                    状态.显示运行模式面板 = true
                } label: {
                    Label("运行模式", systemImage: "circle.grid.2x2.fill")
                }
            }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()
        底部工具栏()
            .environmentObject(新UI状态())
    }
    .background(Color.页面背景)
}
