//
//  页面/功能页面/抓包列表页面.swift
//  sing-box-for-apple 新UI
//
//  骨架阶段 - 数据待对接
//  HTTP 抓包记录列表页面骨架：统计栏、方法筛选胶囊、抓包记录列表、空状态提示
//

import SwiftUI

// MARK: - 页面主体

/// HTTP 抓包列表页面骨架
///
/// 通过 NavigationLink 从配置管理弹窗 push 进入，导航栈由外层弹窗容器提供。
struct 抓包列表页面: View {
    /// 当前选中的方法筛选胶囊（"全部" 表示不过滤）
    @State private var 选中筛选: String = "全部"
    /// 提示文案（占位按钮点击后弹出）
    @State private var 提示: String?

    // TODO: 第六阶段对接官方抓包数据
    /// 方法筛选胶囊选项
    private let 筛选选项: [String] = ["全部", "GET", "POST", "PUT", "DELETE"]

    // TODO: 第六阶段对接官方抓包数据
    /// 抓包记录列表（静态占位，8 条）
    private let 抓包记录列表: [抓包记录占位] = [
        抓包记录占位(方法: "GET",    URL: "https://api.example.com/v1/users",        状态码: 200, 耗时: "45ms", 大小: "1.2 KB", 时间: "10:23:11"),
        抓包记录占位(方法: "POST",   URL: "https://api.example.com/v1/login",        状态码: 200, 耗时: "128ms", 大小: "860 B",  时间: "10:23:09"),
        抓包记录占位(方法: "GET",    URL: "https://cdn.example.com/assets/logo.png", 状态码: 200, 耗时: "22ms",  大小: "58 KB",  时间: "10:23:05"),
        抓包记录占位(方法: "PUT",    URL: "https://api.example.com/v1/users/42",     状态码: 204, 耗时: "67ms",  大小: "0 B",    时间: "10:22:58"),
        抓包记录占位(方法: "GET",    URL: "https://api.example.com/v1/feed",         状态码: 304, 耗时: "19ms",  大小: "0 B",    时间: "10:22:51"),
        抓包记录占位(方法: "DELETE", URL: "https://api.example.com/v1/cache",         状态码: 403, 耗时: "88ms",  大小: "312 B",  时间: "10:22:44"),
        抓包记录占位(方法: "POST",   URL: "https://upload.example.com/file",          状态码: 500, 耗时: "1.2s",  大小: "2.4 KB",  时间: "10:22:30"),
        抓包记录占位(方法: "GET",    URL: "https://static.example.com/index.css",   状态码: 200, 耗时: "14ms",  大小: "9.6 KB",  时间: "10:22:18")
    ]

    /// 根据筛选条件过滤后的记录
    private var 过滤后记录: [抓包记录占位] {
        if 选中筛选 == "全部" { return 抓包记录列表 }
        return 抓包记录列表.filter { $0.方法 == 选中筛选 }
    }

    var body: some View {
        List {
            // MARK: 顶部统计栏
            Section {
                HStack(spacing: 间距常量.标准) {
                    统计指标(标题: "请求总数", 数值: "1,024", 颜色: .主题色)
                    统计指标(标题: "成功", 数值: "986", 颜色: .成功色)
                    统计指标(标题: "失败", 数值: "38", 颜色: .危险色)
                    统计指标(标题: "流量", 数值: "12.4 MB", 颜色: .警告色)
                }
                .padding(.vertical, 间距常量.紧凑)
            }

            // MARK: 方法筛选胶囊
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 间距常量.紧凑) {
                        ForEach(筛选选项, id: \.self) { 选项 in
                            胶囊按钮(文字: 选项, 选中: 选中筛选 == 选项) {
                                选中筛选 = 选项
                            }
                        }
                    }
                    .padding(.vertical, 间距常量.紧凑 / 2)
                }
            }

            // MARK: 抓包记录列表
            Section("抓包记录") {
                if 过滤后记录.isEmpty {
                    EmptyStateView(
                        图标: "tray",
                        标题: "暂无抓包记录",
                        说明: "启动隧道后即可捕获 HTTP 流量"
                    )
                } else {
                    ForEach(过滤后记录) { 记录 in
                        抓包记录行(记录: 记录)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("HTTP 抓包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    提示 = "后续阶段支持"
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("清空记录")
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
    }
}

// MARK: - 子视图

/// 统计指标：标题 + 数值
private struct 统计指标: View {
    /// 指标标题
    let 标题: String
    /// 指标数值
    let 数值: String
    /// 数值颜色
    let 颜色: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(数值)
                .font(字体层级.数据指标)
                .foregroundColor(颜色)
            Text(标题)
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 筛选胶囊按钮
private struct 胶囊按钮: View {
    /// 按钮文字
    let 文字: String
    /// 是否选中
    let 选中: Bool
    /// 点击回调
    let 动作: () -> Void

    var body: some View {
        Button {
            动作()
        } label: {
            Text(文字)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(选中 ? .white : .主题色)
                .padding(.horizontal, 间距常量.中等)
                .padding(.vertical, 6)
                .background(选中 ? Color.主题色 : Color.主题色.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

/// 单条抓包记录行
private struct 抓包记录行: View {
    /// 记录数据
    let 记录: 抓包记录占位

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 间距常量.紧凑) {
                方法徽章(方法: 记录.方法)
                Text(记录.URL)
                    .font(字体层级.正文)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text("\(记录.状态码)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(状态码颜色(记录.状态码))
            }

            HStack(spacing: 间距常量.中等) {
                Text(记录.时间)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                Spacer()
                Text(记录.耗时)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                Text(记录.大小)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
            }
        }
        .padding(.vertical, 间距常量.紧凑 / 2)
    }

    /// 根据状态码返回颜色
    private func 状态码颜色(_ 码: Int) -> Color {
        switch 码 {
        case 200..<300: return .成功色
        case 300..<400: return .警告色
        default:        return .危险色
        }
    }
}

/// HTTP 方法徽章：GET=绿、POST=蓝、PUT=橙、DELETE=红
private struct 方法徽章: View {
    /// HTTP 方法
    let 方法: String

    /// 方法对应颜色
    private var 颜色: Color {
        switch 方法 {
        case "GET":     return .成功色
        case "POST":    return .主题色
        case "PUT":     return .警告色
        case "DELETE":  return .危险色
        default:        return .次要文字
        }
    }

    var body: some View {
        Text(方法)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(颜色)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(颜色.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 圆角常量.小))
            .frame(minWidth: 48)
    }
}

// MARK: - 静态占位数据模型

/// 抓包记录占位模型
private struct 抓包记录占位: Identifiable {
    /// 唯一标识
    let id = UUID()
    /// HTTP 方法
    let 方法: String
    /// 请求 URL
    let URL: String
    /// 状态码
    let 状态码: Int
    /// 耗时
    let 耗时: String
    /// 响应大小
    let 大小: String
    /// 请求时间
    let 时间: String
}

// MARK: - 预览

#Preview {
    NavigationStack {
        抓包列表页面()
    }
}
