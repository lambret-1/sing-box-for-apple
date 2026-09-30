//
//  页面/功能页面/抓包列表页面.swift
//  sing-box-for-apple 新UI
//
//  HTTP 抓包记录列表页面：统计栏、方法筛选、搜索、抓包记录、HAR导出
//

import SwiftUI

// MARK: - 抓包列表页面

/// HTTP 抓包列表页面
struct 抓包列表页面: View {
    @ObservedObject var mitm = MITM状态.共享

    /// 当前选中的方法筛选
    @State private var 选中筛选: String = "全部"
    /// 搜索文本
    @State private var 搜索文本 = ""
    /// 是否显示详情
    @State private var 选中记录: 抓包记录?
    /// 是否显示分享
    @State private var 显示分享 = false
    /// HAR 导出文本
    @State private var HAR文本: String?

    /// 筛选选项
    private let 筛选选项 = ["全部", "GET", "POST", "PUT", "DELETE", "PATCH"]

    /// 过滤后的记录
    private var 过滤后记录: [抓包记录] {
        var 结果 = mitm.抓包记录列表

        // 方法筛选
        if 选中筛选 != "全部" {
            结果 = 结果.filter { $0.方法 == 选中筛选 }
        }

        // 搜索
        if !搜索文本.isEmpty {
            结果 = 结果.filter {
                $0.URL.localizedCaseInsensitiveContains(搜索文本) ||
                $0.域名.localizedCaseInsensitiveContains(搜索文本)
            }
        }

        return 结果
    }

    var body: some View {
        List {
            // MARK: 统计栏
            Section {
                HStack(spacing: 间距常量.标准) {
                    统计指标(标题: "总数", 数值: "\(mitm.抓包记录列表.count)", 颜色: .主题色)
                    统计指标(标题: "成功", 数值: "\(mitm.抓包记录列表.filter { $0.状态码 < 400 }.count)", 颜色: .成功色)
                    统计指标(标题: "失败", 数值: "\(mitm.抓包记录列表.filter { $0.状态码 >= 400 }.count)", 颜色: .危险色)
                    统计指标(标题: "已修改", 数值: "\(mitm.抓包记录列表.filter { $0.已修改 }.count)", 颜色: .警告色)
                }
                .padding(.vertical, 间距常量.紧凑)
            }

            // MARK: 搜索栏
            Section {
                HStack(spacing: 间距常量.紧凑) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.次要文字)
                    TextField("搜索 URL 或域名", text: $搜索文本)
                }
            }

            // MARK: 方法筛选
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

            // MARK: 记录列表
            Section("抓包记录") {
                if 过滤后记录.isEmpty {
                    EmptyStateView(
                        图标: "tray",
                        标题: mitm.抓包记录列表.isEmpty ? "暂无抓包记录" : "无匹配记录",
                        说明: mitm.抓包记录列表.isEmpty ? "启动隧道并开启 MITM 后即可捕获 HTTP 流量" : "尝试调整筛选条件"
                    )
                } else {
                    ForEach(过滤后记录) { 记录 in
                        抓包记录行(记录: 记录)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                选中记录 = 记录
                            }
                    }
                    .onDelete { 索引集 in
                        mitm.抓包记录列表.remove(atOffsets: 索引集)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("HTTP 抓包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        导出HAR()
                    } label: {
                        Label("导出 HAR", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        mitm.清空抓包记录()
                    } label: {
                        Label("清空记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $选中记录) { 记录 in
            抓包详情页面(记录: 记录)
        }
        .sheet(isPresented: $显示分享) {
            if let har = HAR文本, let data = har.data(using: .utf8) {
                ShareSheet(items: [data])
            }
        }
    }

    // MARK: - 方法

    /// 导出 HAR
    private func 导出HAR() {
        HAR文本 = mitm.导出HAR()
        显示分享 = true
    }
}

// MARK: - 子视图

/// 统计指标
private struct 统计指标: View {
    let 标题: String
    let 数值: String
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
    let 文字: String
    let 选中: Bool
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
    let 记录: 抓包记录

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
                Text(记录.时间, style: .time)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                Spacer()
                if 记录.已修改, let 脚本名 = 记录.匹配脚本 {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.警告色)
                    Text(脚本名)
                        .font(字体层级.辅助说明)
                        .foregroundColor(.警告色)
                }
                Text(记录.格式化耗时)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
                Text(记录.格式化响应大小)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
            }
        }
        .padding(.vertical, 间距常量.紧凑 / 2)
    }

    private func 状态码颜色(_ 码: Int) -> Color {
        switch 码 {
        case 200..<300: return .成功色
        case 300..<400: return .警告色
        default:        return .危险色
        }
    }
}

/// HTTP 方法徽章
private struct 方法徽章: View {
    let 方法: String

    private var 颜色: Color {
        switch 方法 {
        case "GET":     return .成功色
        case "POST":    return .主题色
        case "PUT":     return .警告色
        case "DELETE":  return .危险色
        case "PATCH":   return .绿色文字
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

// MARK: - 抓包详情页面

/// 抓包详情页面
struct 抓包详情页面: View {
    let 记录: 抓包记录
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            List {
                // MARK: 请求概览
                Section("请求概览") {
                    详情行(标签: "方法", 值: 记录.方法)
                    详情行(标签: "URL", 值: 记录.URL)
                    详情行(标签: "域名", 值: 记录.域名)
                    详情行(标签: "时间", 值: 记录.时间.formatted())
                    详情行(标签: "耗时", 值: 记录.格式化耗时)
                    详情行(标签: "大小", 值: "请求 \(抓包记录.格式化字节数(记录.请求大小)) / 响应 \(记录.格式化响应大小)")
                }

                // MARK: 响应状态
                Section("响应") {
                    HStack {
                        Text("状态码")
                            .font(字体层级.正文)
                            .foregroundColor(.次要文字)
                        Spacer()
                        Text("\(记录.状态码)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(状态码颜色(记录.状态码))
                    }
                }

                // MARK: 请求头
                Section("请求头") {
                    ForEach(Array(记录.请求头.keys.sorted()), id: \.self) { 键 in
                        详情行(标签: 键, 值: 记录.请求头[键] ?? "")
                    }
                }

                // MARK: 响应头
                Section("响应头") {
                    ForEach(Array(记录.响应头.keys.sorted()), id: \.self) { 键 in
                        详情行(标签: 键, 值: 记录.响应头[键] ?? "")
                    }
                }

                // MARK: 请求体
                if !记录.请求体.isEmpty {
                    Section("请求体") {
                        Text(记录.请求体)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.次要文字)
                            .textSelection(.enabled)
                    }
                }

                // MARK: 响应体
                if !记录.响应体.isEmpty {
                    Section("响应体") {
                        Text(记录.响应体)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.次要文字)
                            .textSelection(.enabled)
                    }
                }

                // MARK: 脚本修改信息
                if 记录.已修改 {
                    Section("脚本修改") {
                        if let 脚本名 = 记录.匹配脚本 {
                            详情行(标签: "匹配脚本", 值: 脚本名)
                        }
                        StateBadge(文字: "此请求已被脚本修改", 类型: .警告, 带圆点: true)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("抓包详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { 关闭() }
                }
            }
        }
    }

    private func 详情行(标签: String, 值: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(标签)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.次要文字)
            Text(值)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func 状态码颜色(_ 码: Int) -> Color {
        switch 码 {
        case 200..<300: return .成功色
        case 300..<400: return .警告色
        default:        return .危险色
        }
    }
}

// MARK: - 分享 Sheet

/// 系统分享 Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 预览

#Preview {
    NavigationStack {
        抓包列表页面()
    }
}
