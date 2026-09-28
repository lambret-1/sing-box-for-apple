import SwiftUI
import Library
import Libbox

// MARK: - 新UI主页面

/// 新UI主页面：顶部状态区 + 功能卡片栏 + 内容区 + 底部工具栏
public struct 新UIDashboardView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @State private var 当前底部标签: 新UI底部标签 = .节点
    @State private var 当前顶部卡片: 新UI顶部卡片 = .CPU
    @State private var CPU使用率: Double = 0
    @State private var 内存占用: UInt64 = 0
    @State private var 显示设置 = false

    private var profile: ExtensionProfile? {
        environments.extensionProfile
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 顶部状态区
            顶部状态区()
                .padding(.horizontal, 新UI间距.标准)
                .padding(.top, 新UI间距.小)

            // 顶部功能卡片栏
            新UI顶部功能卡片栏(
                当前卡片: $当前顶部卡片,
                CPU使用率: CPU使用率,
                内存占用: 内存占用,
                扩展内存: 0,
                TCP连接数: 连接数
            )

            // 内容区
            ScrollView {
                VStack(spacing: 新UI间距.标准) {
                    内容区()
                        .padding(.bottom, 新UI间距.标准)
                }
            }

            // 底部工具栏
            新UI底部工具栏(当前标签: $当前底部标签)
        }
        .background(Color.页面背景.ignoresSafeArea())
        .sheet(isPresented: $显示设置) {
            新UISettingsView()
        }
        .onAppear {
            开始监控系统资源()
        }
        .onDisappear {
            停止监控系统资源()
        }
    }

    // MARK: - 顶部状态区

    private func 顶部状态区() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(状态文字)
                    .font(新UIFont.大标题)
                    .foregroundColor(状态文字颜色)

                if let 当前节点 = 当前节点名称 {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 10))
                            .foregroundColor(新UI颜色.次文字)
                        Text(当前节点)
                            .font(.system(size: 12))
                            .foregroundColor(新UI颜色.次文字)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(spacing: 8) {
                // VPN开关
                Toggle("", isOn: Binding(
                    get: { profile?.status.isConnected ?? false },
                    set: { 新值 in
                        if 新值 {
                            profile?.start()
                        } else {
                            profile?.stop()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(新UI颜色.成功)

                // 设置按钮
                Button {
                    显示设置 = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(新UI颜色.次文字)
                }
            }
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private func 内容区() -> some View {
        switch 当前底部标签 {
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

    // MARK: - 节点内容区

    private func 节点内容区() -> some View {
        VStack(spacing: 新UI间距.标准) {
            新UIAppCard(标题: "节点列表") {
                if 节点列表.isEmpty {
                    新UIEmptyStateView(图标: "server.rack", 标题: "暂无节点", 说明: "请在设置中导入订阅或手动添加节点")
                } else {
                    ForEach(节点列表, id: \.self) { 节点 in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(节点)
                                .font(新UIFont.正文)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 新UI间距.标准)
    }

    // MARK: - 策略组内容区

    private func 策略组内容区() -> some View {
        VStack(spacing: 新UI间距.标准) {
            新UIAppCard(标题: "策略组") {
                新UIEmptyStateView(图标: "circle.grid.2x2.fill", 标题: "策略组管理", 说明: "功能开发中")
            }
        }
        .padding(.horizontal, 新UI间距.标准)
    }

    // MARK: - 网络活动内容区

    private func 网络活动内容区() -> some View {
        VStack(spacing: 新UI间距.标准) {
            新UIAppCard(标题: "网络活动") {
                if 连接列表.isEmpty {
                    新UIEmptyStateView(图标: "antenna.radiowaves.left.and.right", 标题: "暂无活动连接", 说明: "开启VPN后显示实时连接")
                } else {
                    ForEach(连接列表.prefix(20), id: \.id) { 连接 in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(连接.network.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(连接.network.lowercased() == "tcp" ? 新UI颜色.信息 : 新UI颜色.警告)
                                    .cornerRadius(2)
                                Text(连接.destination)
                                    .font(新UIFont.辅助说明)
                                    .lineLimit(1)
                                Spacer()
                                Text(新UI格式化字节(Int64(连接.upload + 连接.download)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(新UI颜色.次文字)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 新UI间距.标准)
    }

    // MARK: - 规则与日志内容区

    private func 规则与日志内容区() -> some View {
        VStack(spacing: 新UI间距.标准) {
            新UIAppCard(标题: "分流规则") {
                新UIEmptyStateView(图标: "arrow.triangle.branch", 标题: "分流规则管理", 说明: "功能开发中")
            }
            新UIAppCard(标题: "调试日志") {
                新UIEmptyStateView(图标: "ladybug", 标题: "调试日志", 说明: "功能开发中")
            }
        }
        .padding(.horizontal, 新UI间距.标准)
    }

    // MARK: - 数据属性

    private var 状态文字: String {
        guard let profile = profile else { return "未加载" }
        switch profile.status {
        case .disconnected: return "已停止"
        case .connecting: return "连接中"
        case .connected: return "运行中"
        case .reasserting: return "重连中"
        case .disconnecting: return "停止中"
        default: return "未知"
        }
    }

    private var 状态文字颜色: Color {
        profile?.status.isConnected ?? false ? 新UI颜色.运行中 : 新UI颜色.已停止
    }

    private var 当前节点名称: String? {
        // 从profile中获取当前节点名称
        return nil
    }

    private var 节点列表: [String] {
        // 从profile中获取节点列表
        return []
    }

    private var 连接列表: [Connection] {
        environments.commandClient.connections
    }

    private var 连接数: Int {
        连接列表.filter { $0.closedAt == nil }.count
    }

    // MARK: - 系统资源监控

    private var 监控定时器: DispatchSourceTimer?

    private func 开始监控系统资源() {
        let 定时器 = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "newui.monitor", qos: .utility))
        定时器.schedule(deadline: .now() + 2, repeating: 2)
        定时器.setEventHandler {
            let cpu = 获取CPU使用率()
            let mem = 获取内存占用()
            DispatchQueue.main.async {
                self.CPU使用率 = cpu
                self.内存占用 = mem
            }
        }
        定时器.resume()
        监控定时器 = 定时器
    }

    private func 停止监控系统资源() {
        监控定时器?.cancel()
        监控定时器 = nil
    }

    private func 获取CPU使用率() -> Double {
        var 任务 = mach_task_self_
        var 线程数: mach_msg_type_number_t = 0
        var 线程列表: thread_act_array_t?
        guard task_threads(任务, &线程列表, &线程数) == KERN_SUCCESS else { return 0 }
        var 总使用时间: UInt64 = 0
        if let 列表 = 线程列表 {
            for 索引 in 0..<Int(线程数) {
                var 线程信息 = thread_basic_info()
                var 信息数 = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
                let 结果 = withUnsafeMutablePointer(to: &线程信息) { 指针 in
                    指针.withMemoryRebound(to: integer_t.self, capacity: Int(信息数)) { 重绑定指针 in
                        thread_info(列表[索引], UInt32(THREAD_BASIC_INFO), 重绑定指针, &信息数)
                    }
                }
                if 结果 == KERN_SUCCESS {
                    总使用时间 += UInt64(max(0, 线程信息.user_time.seconds)) * 1_000_000 + UInt64(max(0, 线程信息.user_time.microseconds))
                    总使用时间 += UInt64(max(0, 线程信息.system_time.seconds)) * 1_000_000 + UInt64(max(0, 线程信息.system_time.microseconds))
                }
            }
        }
        if let 列表 = 线程列表, 线程数 > 0 {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: 列表)), vm_size_t(Int(线程数) * MemoryLayout<thread_t>.size))
        }
        return min(Double(总使用时间) / 100000.0, 100)
    }

    private func 获取内存占用() -> UInt64 {
        var 任务信息 = mach_task_basic_info()
        var 信息数 = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let 结果 = withUnsafeMutablePointer(to: &任务信息) { 指针 in
            指针.withMemoryRebound(to: integer_t.self, capacity: Int(信息数)) { 重绑定指针 in
                task_info(mach_task_self_, 20, 重绑定指针, &信息数)
            }
        }
        guard 结果 == KERN_SUCCESS else { return 0 }
        return 任务信息.resident_size
    }
}

// MARK: - 设置页面（占位）

/// 新UI设置页面
public struct 新UISettingsView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("隧道") {
                    NavigationLink {
                        SettingView()
                            .navigationTitle("设置")
                    } label: {
                        Label("系统设置", systemImage: "gearshape")
                    }
                    NavigationLink {
                        ToolsView()
                            .navigationTitle("工具")
                    } label: {
                        Label("工具", systemImage: "terminal.fill")
                    }
                }
                Section("网络") {
                    NavigationLink {
                        Text("DNS 设置").navigationTitle("DNS")
                    } label: {
                        Label("DNS 设置", systemImage: "network")
                    }
                    NavigationLink {
                        Text("MITM 解密").navigationTitle("MITM")
                    } label: {
                        Label("MITM 解密", systemImage: "lock.shield")
                    }
                    NavigationLink {
                        Text("HTTP 抓包").navigationTitle("抓包")
                    } label: {
                        Label("HTTP 抓包", systemImage: "doc.text.magnifyingglass")
                    }
                    NavigationLink {
                        Text("重写规则").navigationTitle("重写")
                    } label: {
                        Label("重写规则", systemImage: "pencil.and.outline")
                    }
                }
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
