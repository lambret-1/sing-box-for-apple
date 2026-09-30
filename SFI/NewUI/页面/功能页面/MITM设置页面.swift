//
//  页面/功能页面/MITM设置页面.swift
//  sing-box-for-apple 新UI
//
//  HTTPS 中间人解密设置页面：MITM 开关、证书状态、证书操作、域名排除、TLS指纹
//

import SwiftUI
import UIKit

// MARK: - 页面主体

/// MITM 设置页面
struct MITM设置页面: View {
    /// MITM 全局状态
    @ObservedObject var mitm = MITM状态.共享

    /// 提示文案
    @State private var 提示: String?
    /// 是否显示证书详情
    @State private var 显示证书详情 = false
    /// 新排除域名输入
    @State private var 新排除域名 = ""
    /// 新排除备注
    @State private var 新排除备注 = ""
    /// 是否显示文档导出器
    @State private var 显示文档导出 = false
    /// 是否显示安装引导
    @State private var 显示安装引导 = false
    /// 待导出的文件 URL
    @State private var 待导出文件: URL?
    /// 是否显示重新生成确认
    @State private var 显示重新生成确认 = false

    var body: some View {
        List {
            // MARK: 总开关
            Section {
                AppFormRow(标签: "启用 MITM", 说明: "解密 HTTPS 流量以进行抓包与重写（需安装根证书）") {
                    Toggle("", isOn: $mitm.启用MITM).labelsHidden()
                }

                AppFormRow(标签: "抓包日志", 说明: "记录 HTTP 请求/响应日志用于分析") {
                    Toggle("", isOn: $mitm.启用抓包).labelsHidden()
                }

                AppFormRow(标签: "HTTP/2 支持", 说明: "解密 HTTP/2 流量（兼容性可能下降）") {
                    Toggle("", isOn: $mitm.启用HTTP2).labelsHidden()
                }
            }

            // MARK: TLS 指纹
            Section("TLS 指纹模拟") {
                Picker("指纹类型", selection: $mitm.TLS指纹) {
                    ForEach(TLS指纹类型.allCases) { 类型 in
                        Text(类型.显示名称).tag(类型)
                    }
                }
                Text("模拟浏览器 TLS 握手指纹，降低 WAF 识别概率")
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
            }

            // MARK: 证书状态
            Section("证书状态") {
                HStack(spacing: 间距常量.中等) {
                    Image(systemName: 证书状态图标)
                        .foregroundColor(证书状态颜色)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(证书状态标题)
                            .font(字体层级.正文)
                            .foregroundColor(.primary)
                        Text(mitm.证书状态.描述)
                            .font(字体层级.辅助说明)
                            .foregroundColor(.次要文字)
                    }
                    Spacer()
                    StateBadge(文字: 证书状态徽标文字, 类型: 证书状态徽标类型, 带圆点: true)
                }
                .padding(.vertical, 间距常量.紧凑 / 2)

                Button {
                    显示证书详情 = true
                } label: {
                    HStack {
                        Text("查看证书详情")
                            .font(字体层级.正文)
                            .foregroundColor(.主题色)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.次要文字)
                    }
                }
            }

            // MARK: 证书错误提示
            if let 错误信息 = mitm.证书生成错误 {
                Section {
                    HStack(spacing: 间距常量.中等) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.危险色)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("证书生成失败")
                                .font(字体层级.卡片标题)
                                .foregroundColor(.危险色)
                            Text(错误信息)
                                .font(字体层级.辅助说明)
                                .foregroundColor(.次要文字)
                        }
                        Spacer()
                    }
                    Button("重试生成") {
                        do {
                            try mitm.重新生成证书()
                        } catch {
                            mitm.证书生成错误 = error.localizedDescription
                        }
                    }
                    .font(字体层级.按钮文字)
                    .foregroundColor(.主题色)
                }
            }

            // MARK: 证书操作
            Section("证书操作") {
                证书操作行(图标: "square.and.arrow.up", 标题: "导出证书", 说明: "导出 .mobileconfig 描述文件供安装") {
                    导出证书()
                }
                证书操作行(图标: "graduationcap", 标题: "安装引导", 说明: "三步引导完成证书安装与信任") {
                    显示安装引导 = true
                }

                // 用户确认安装按钮
                if case .未安装 = mitm.证书状态 {
                    Button {
                        mitm.用户确认已安装信任()
                    } label: {
                        HStack(spacing: 间距常量.中等) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.成功色)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("我已安装并信任")
                                    .font(字体层级.正文)
                                    .foregroundColor(.primary)
                                Text("点击确认证书已安装完成")
                                    .font(字体层级.辅助说明)
                                    .foregroundColor(.次要文字)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 间距常量.紧凑 / 2)
                    }
                }

                证书操作行(图标: "arrow.triangle.2.circlepath", 标题: "重新生成", 说明: "生成新的 CA 证书（旧证书将失效）") {
                    显示重新生成确认 = true
                }
            }

            // MARK: 域名排除
            Section {
                ForEach(mitm.域名排除列表) { 项 in
                    HStack(spacing: 间距常量.中等) {
                        Image(systemName: "nosign")
                            .foregroundColor(.次要文字)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(项.域名)
                                .font(字体层级.正文)
                                .foregroundColor(.primary)
                            if !项.备注.isEmpty {
                                Text(项.备注)
                                    .font(字体层级.辅助说明)
                                    .foregroundColor(.次要文字)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { 项.启用 },
                            set: { _ in
                                if let 索引 = mitm.域名排除列表.firstIndex(where: { $0.id == 项.id }) {
                                    mitm.域名排除列表[索引].启用.toggle()
                                }
                            }
                        )).labelsHidden()
                    }
                }
                .onDelete(perform: 删除域名排除)

                HStack {
                    TextField("添加排除域名（如 *.example.com）", text: $新排除域名)
                        .font(字体层级.正文)
                    Button("添加") {
                        添加域名排除()
                    }
                    .disabled(新排除域名.isEmpty)
                }
            } header: {
                HStack {
                    Text("域名排除（不解密）")
                    Spacer()
                    EditButton()
                        .font(字体层级.辅助说明)
                }
            } footer: {
                Text("对这些域名跳过 MITM 解密，直接透传原始 TLS，适用于强 WAF 站点")
            }

            // MARK: 功能入口
            Section("高级功能") {
                NavigationLink {
                    圈X脚本列表页面()
                } label: {
                    功能入口行(图标: "curlybraces", 标题: "圈 X 脚本", 说明: "自定义 JS 请求/响应脚本", 数量: mitm.脚本列表.filter { $0.启用 }.count)
                }

                NavigationLink {
                    重写规则设置页面()
                } label: {
                    功能入口行(图标: "arrow.triangle.turn.up.right.diamond", 标题: "重写规则", 说明: "URL/请求头/响应体重写", 数量: mitm.重写规则列表.filter { $0.启用 }.count)
                }

                NavigationLink {
                    抓包列表页面()
                } label: {
                    功能入口行(图标: "doc.text.magnifyingglass", 标题: "HTTP 抓包", 说明: "查看捕获的 HTTP 请求记录", 数量: mitm.抓包记录列表.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("MITM 解密")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: Binding(
            get: { 提示 != nil },
            set: { if !$0 { 提示 = nil } }
        )) {
            Button("好", role: .cancel) { 提示 = nil }
        } message: {
            Text(提示 ?? "")
        }
        .sheet(isPresented: $显示证书详情) {
            证书详情页面()
        }
        .sheet(isPresented: $显示文档导出) {
            if let 文件 = 待导出文件 {
               文档导出器(url: 文件)
            }
        }
        .sheet(isPresented: $显示安装引导) {
            证书安装引导页面()
        }
        .confirmationDialog("重新生成证书", isPresented: $显示重新生成确认, titleVisibility: .visible) {
            Button("重新生成", role: .destructive) {
                重新生成证书()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("重新生成后，旧证书将失效，需要重新安装描述文件。确定继续吗？")
        }
    }

    // MARK: - 计算属性

    private var 证书状态图标: String {
        switch mitm.证书状态 {
        case .就绪: return "checkmark.shield.fill"
        case .未安装: return "arrow.down.circle.dotted"
        case .未信任: return "lock.shield"
        case .文件缺失: return "questionmark.folder"
        case .已过期: return "exclamationmark.triangle"
        case .文件损坏: return "xmark.shield"
        case .临近过期: return "clock.badge.exclamationmark"
        }
    }

    private var 证书状态颜色: Color {
        switch mitm.证书状态 {
        case .就绪: return .成功色
        case .未安装, .未信任: return .警告色
        case .文件缺失, .已过期, .文件损坏: return .危险色
        case .临近过期: return .警告色
        }
    }

    private var 证书状态标题: String {
        switch mitm.证书状态 {
        case .就绪: return "证书已就绪"
        case .未安装: return "证书未安装"
        case .未信任: return "证书未信任"
        case .文件缺失: return "证书文件缺失"
        case .已过期: return "证书已过期"
        case .文件损坏: return "证书已损坏"
        case .临近过期: return "证书即将过期"
        }
    }

    private var 证书状态徽标文字: String {
        switch mitm.证书状态 {
        case .就绪: return "正常"
        case .未安装: return "待安装"
        case .未信任: return "待信任"
        case .文件缺失: return "缺失"
        case .已过期: return "过期"
        case .文件损坏: return "损坏"
        case .临近过期(let 天数): return "\(天数)天"
        }
    }

    private var 证书状态徽标类型: StateBadge类型 {
        switch mitm.证书状态 {
        case .就绪: return .成功
        case .未安装, .未信任, .临近过期: return .警告
        case .文件缺失, .已过期, .文件损坏: return .错误
        }
    }

    // MARK: - 方法

    /// 导出证书（生成 mobileconfig 并弹出文档导出器）
    private func 导出证书() {
        do {
            let 文件 = try mitm.导出MobileConfig()
            待导出文件 = 文件
            显示文档导出 = true
        } catch {
            提示 = "证书导出失败：\(error.localizedDescription)"
        }
    }

    /// 重新生成证书
    private func 重新生成证书() {
        do {
            try mitm.重新生成证书()
            提示 = "证书已重新生成，请重新安装描述文件"
        } catch {
            提示 = "证书生成失败：\(error.localizedDescription)"
        }
    }

    private func 添加域名排除() {
        let 域名 = 新排除域名.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !域名.isEmpty else { return }
        mitm.域名排除列表.append(域名排除项(域名: 域名, 备注: "", 启用: true))
        新排除域名 = ""
    }

    private func 删除域名排除(at offsets: IndexSet) {
        mitm.域名排除列表.remove(atOffsets: offsets)
    }
}

// MARK: - 子视图

private struct 证书操作行: View {
    let 图标: String
    let 标题: String
    let 说明: String
    let 动作: () -> Void

    var body: some View {
        Button {
            动作()
        } label: {
            HStack(spacing: 间距常量.中等) {
                Image(systemName: 图标)
                    .foregroundColor(.主题色)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(标题)
                        .font(字体层级.正文)
                        .foregroundColor(.primary)
                    Text(说明)
                        .font(字体层级.辅助说明)
                        .foregroundColor(.次要文字)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.次要文字)
            }
            .padding(.vertical, 间距常量.紧凑 / 2)
        }
    }
}

private struct 功能入口行: View {
    let 图标: String
    let 标题: String
    let 说明: String
    let 数量: Int

    var body: some View {
        HStack(spacing: 间距常量.中等) {
            Image(systemName: 图标)
                .foregroundColor(.主题色)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(标题)
                    .font(字体层级.正文)
                    .foregroundColor(.primary)
                Text(说明)
                    .font(字体层级.辅助说明)
                    .foregroundColor(.次要文字)
            }
            Spacer()
            if 数量 > 0 {
                StateBadge(文字: "\(数量)", 类型: .信息, 带圆点: false)
            }
        }
        .padding(.vertical, 间距常量.紧凑 / 2)
    }
}

// MARK: - 证书详情页面

struct 证书详情页面: View {
    @ObservedObject var mitm = MITM状态.共享
    @Environment(\.dismiss) private var 关闭

    var body: some View {
        NavigationStack {
            List {
                Section("证书信息") {
                    详情行(标签: "颁发者", 值: "sing-box MITM CA")
                    详情行(标签: "有效期", 值: "10 年（自生成起）")
                    详情行(标签: "密钥类型", 值: "RSA 2048")
                    详情行(标签: "指纹算法", 值: "SHA-256")
                }

                Section("证书内容（PEM）") {
                    Text(mitm.CA证书PEM)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.次要文字)
                        .textSelection(.enabled)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("证书详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { 关闭() }
                }
            }
        }
    }

    private func 详情行(标签: String, 值: String) -> some View {
        HStack {
            Text(标签)
                .font(字体层级.正文)
                .foregroundColor(.次要文字)
            Spacer()
            Text(值)
                .font(字体层级.正文)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 文档导出器（UIDocumentPickerViewController 封装）

/// 文档导出器：将文件导出到"文件"App 或分享菜单
struct 文档导出器: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

// MARK: - 证书安装引导页面

/// 证书安装三步引导
struct 证书安装引导页面: View {
    @Environment(\.dismiss) private var 关闭
    @ObservedObject var mitm = MITM状态.共享
    @State private var 当前步骤 = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 步骤指示器
                步骤指示器
                    .padding()

                // 步骤内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 间距常量.宽松) {
                        switch 当前步骤 {
                        case 1:
                            步骤一内容
                        case 2:
                            步骤二内容
                        case 3:
                            步骤三内容
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }

                // 底部按钮
                底部按钮
                    .padding()
            }
            .navigationTitle("证书安装引导")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { 关闭() }
                }
            }
        }
    }

    // MARK: 步骤指示器

    private var 步骤指示器: some View {
        HStack(spacing: 间距常量.中等) {
            ForEach(1...3, id: \.self) { 步骤 in
                Circle()
                    .fill(步骤 <= 当前步骤 ? Color.主题色 : Color.次要文字.opacity(0.3))
                    .frame(width: 12, height: 12)
                if 步骤 < 3 {
                    Rectangle()
                        .fill(步骤 < 当前步骤 ? Color.主题色 : Color.次要文字.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }

    // MARK: 步骤内容

    private var 步骤一内容: some View {
        VStack(alignment: .leading, spacing: 间距常量.中等) {
            Text("第一步：安装描述文件")
                .font(字体层级.卡片标题)

            Text("""
            1. 点击下方"导出证书"按钮
            2. 在弹出的分享菜单中选择"保存到文件"或"更多"
            3. 选择保存位置（如"我的 iPhone"）
            4. 打开 iOS"设置"App
            5. 点击顶部"已下载描述文件"
            6. 点击右上角"安装"，输入密码确认
            """)
            .font(字体层级.正文)
            .foregroundColor(.次要文字)
            .lineSpacing(4)
        }
    }

    private var 步骤二内容: some View {
        VStack(alignment: .leading, spacing: 间距常量.中等) {
            Text("第二步：启用完全信任")
                .font(字体层级.卡片标题)

            Text("""
            1. 打开 iOS"设置"App
            2. 进入"通用" → "关于本机"
            3. 滚动到底部，点击"证书信任设置"
            4. 找到"sing-box MITM CA"
            5. 开启右侧开关
            6. 在弹窗中点击"继续"
            """)
            .font(字体层级.正文)
            .foregroundColor(.次要文字)
            .lineSpacing(4)
        }
    }

    private var 步骤三内容: some View {
        VStack(alignment: .leading, spacing: 间距常量.中等) {
            Text("第三步：完成")
                .font(字体层级.卡片标题)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.成功色)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()

            Text("""
            证书已安装并信任完成。

            现在可以返回 MITM 设置页面，开启 MITM 总开关开始抓包。

            首次使用时，建议先开启"抓包日志"，然后访问几个 HTTPS 网站验证抓包功能是否正常。
            """)
            .font(字体层级.正文)
            .foregroundColor(.次要文字)
            .lineSpacing(4)
        }
    }

    // MARK: 底部按钮

    private var 底部按钮: some View {
        VStack(spacing: 间距常量.中等) {
            if 当前步骤 < 3 {
                Button {
                    withAnimation { 当前步骤 += 1 }
                } label: {
                    Text("下一步")
                        .font(字体层级.按钮文字)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.主题色)
                        .cornerRadius(圆角常量.标准)
                }

                Button("上一步") {
                    withAnimation { 当前步骤 -= 1 }
                }
                .font(字体层级.辅助说明)
                .foregroundColor(.次要文字)
                .opacity(当前步骤 > 1 ? 1 : 0)
            } else {
                Button {
                    mitm.刷新证书状态()
                    关闭()
                } label: {
                    Text("完成")
                        .font(字体层级.按钮文字)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.主题色)
                        .cornerRadius(圆角常量.标准)
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        MITM设置页面()
    }
}
