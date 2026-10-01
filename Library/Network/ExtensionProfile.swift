import Foundation
import Libbox
import NetworkExtension
import os
#if os(iOS)
    import FileProvider
#endif

private let logger = Logger(category: "ExtensionProfile")

@MainActor
public class ExtensionProfile: ObservableObject {
    public static let controlKind = AppConfiguration.widgetControlKind

    private let manager: NEVPNManager?
    private var connection: NEVPNConnection?
    private var observer: Any?
    private let isMock: Bool

    @Published public var status: NEVPNStatus
    @Published public var connectedDate: Date?

    public init(_ manager: NEVPNManager) {
        self.manager = manager
        connection = manager.connection
        status = manager.connection.status
        connectedDate = manager.connection.connectedDate
        isMock = false
    }

    private init(mockStatus: NEVPNStatus, mockConnectedDate: Date?) {
        manager = nil
        connection = nil
        status = mockStatus
        connectedDate = mockConnectedDate
        isMock = true
    }

    private static var _mock: ExtensionProfile?

    public static var mock: ExtensionProfile {
        if _mock == nil {
            _mock = ExtensionProfile(mockStatus: .connected, mockConnectedDate: Date().addingTimeInterval(-3600))
        }
        return _mock!
    }

    public func register() {
        guard !isMock, let manager else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NEVPNStatusDidChange,
            object: manager.connection,
            queue: nil
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else {
                return
            }
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.connection = connection
                self.status = connection.status
                self.connectedDate = connection.connectedDate
                if connection.status == .disconnected {
                    Self.schedulePromoteOOMDraft()
                }
                #if os(iOS)
                    if #available(iOS 16.0, *) {
                        if connection.status == .connected || connection.status == .disconnected {
                            Self.signalFileProviderChanges()
                        }
                    }
                #endif
            }
        }
    }

    private static func schedulePromoteOOMDraft() {
        Task.detached {
            try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
            #if os(macOS)
                if Variant.useSystemExtension {
                    guard HelperServiceManager.rootHelperStatus == .enabled else {
                        return
                    }
                    do {
                        try RootHelperClient.shared.promoteOOMDraft()
                    } catch {
                        logger.warning("promote OOM draft: \(error.localizedDescription)")
                    }
                    return
                }
            #endif
            LibboxPromoteOOMDraft()
        }
    }

    #if os(iOS)
        @available(iOS 16.0, *)
        private static func signalFileProviderChanges() {
            Task.detached {
                guard let domain = try? await NSFileProviderManager.domains()
                    .first(where: { $0.identifier.rawValue == AppConfiguration.fileProviderDomainID }),
                    let manager = NSFileProviderManager(for: domain)
                else {
                    return
                }
                try? await manager.signalEnumerator(for: .workingSet)
            }
        }
    #endif

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private static func makeDefaultOnDemandRules() -> [NEOnDemandRule] {
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any
        rule.probeURL = URL(string: "http://captive.apple.com")
        return [rule]
    }

    private func setOnDemandRules(useDefaultRules: Bool) async {
        guard let manager else { return }
        if useDefaultRules {
            manager.onDemandRules = Self.makeDefaultOnDemandRules()
        } else {
            let rules = await SharedPreferences.onDemandRules.get()
            manager.onDemandRules = rules.isEmpty ? Self.makeDefaultOnDemandRules() : rules.map { $0.toNERule() }
        }
    }

    public func updateOnDemand(enabled: Bool, useDefaultRules: Bool) async throws {
        guard let manager else { return }
        manager.isOnDemandEnabled = enabled
        if !enabled {
            if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
                var config = proto.providerConfiguration ?? [:]
                if config.removeValue(forKey: "wasOnDemandEnabled") != nil {
                    proto.providerConfiguration = config
                }
            }
        }
        await setOnDemandRules(useDefaultRules: useDefaultRules)
        try await manager.saveToPreferences()
    }

    @available(iOS 16.0, macOS 13.0, tvOS 17.0, *)
    public func fetchLastDisconnectError() async throws {
        guard let connection else { return }
        try await connection.fetchLastDisconnectError()
    }

    public func start() async throws {
        if isMock {
            status = .connecting
            try await Task.sleep(nanoseconds: 500_000_000)
            status = .connected
            connectedDate = Date()
            return
        }
        guard let manager else { return }
        try await fetchProfile()
        manager.isEnabled = true
        let alwaysOn = await SharedPreferences.alwaysOn.get()
        let onDemandEnabled = await SharedPreferences.onDemandEnabled.get()
        if alwaysOn || onDemandEnabled {
            manager.isOnDemandEnabled = true
            await setOnDemandRules(useDefaultRules: alwaysOn)
        }
        if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
            var config = proto.providerConfiguration ?? [:]
            if config.removeValue(forKey: "wasOnDemandEnabled") != nil {
                proto.providerConfiguration = config
            }
        }
        #if !os(tvOS)
            if let protocolConfiguration = manager.protocolConfiguration {
                let includeAllNetworks = await SharedPreferences.includeAllNetworks.get()
                protocolConfiguration.includeAllNetworks = includeAllNetworks
                protocolConfiguration.excludeLocalNetworks = await SharedPreferences.excludeLocalNetworks.get()
                protocolConfiguration.enforceRoutes = await SharedPreferences.enforceRoutes.get()
                if #available(iOS 16.4, macOS 13.3, *) {
                    protocolConfiguration.excludeAPNs = await SharedPreferences.excludeAPNs.get()
                    protocolConfiguration.excludeCellularServices = await SharedPreferences.excludeCellularServices.get()
                }
                if #available(iOS 17.4, macOS 14.4, *) {
                    protocolConfiguration.excludeDeviceCommunication = await SharedPreferences.excludeDeviceCommunication.get()
                }
            }
        #endif
        try await manager.saveToPreferences()
        let options = try await prepareStartOptions()
        try manager.connection.startVPNTunnel(options: options)
    }

    public func reloadService() async throws {
        if isMock {
            return
        }
        let options = try await prepareStartOptions()
        let data = try ExtensionStartOptions.encode(options)
        guard let session = connection as? NETunnelProviderSession else {
            throw NSError(domain: "ExtensionStartOptions", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Tunnel session unavailable",
            ])
        }
        let response = try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(data) { response in
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        if let response, !response.isEmpty {
            let message = String(data: response, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ExtensionStartOptions", code: -1, userInfo: [
                NSLocalizedDescriptionKey: message,
            ])
        }
    }

    private func prepareStartOptions() async throws -> [String: NSObject] {
        var options: [String: NSObject] = [
            "manualStart": NSNumber(value: true),
            "locale": NSString(string: ApplicationLocale.preferredIdentifier),
        ]

        let profileID = await SharedPreferences.selectedProfileID.get()
        guard let profile = try await ProfileManager.get(profileID) else {
            throw NSError(domain: "ExtensionProfile", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Missing selected profile",
            ])
        }

        var configContent = try await profile.readAsync()

        // 注入 MITM 配置（如已启用）
        configContent = Self.注入MITM配置(到: configContent)

        options["configContent"] = NSString(string: configContent)

        #if os(macOS)
            options["oomKillerEnabled"] = await NSNumber(value: SharedPreferences.oomKillerEnabled.get())
            options["oomMemoryLimitMB"] = await NSNumber(value: SharedPreferences.oomMemoryLimitMB.get())
            options["oomKillerKillConnections"] = await NSNumber(value: SharedPreferences.oomKillerKillConnections.get())
        #endif
        options["powerReportEnabled"] = await NSNumber(value: SharedPreferences.powerReportEnabled.get())
        options["systemProxyEnabled"] = await NSNumber(value: SharedPreferences.systemProxyEnabled.get())
        options["excludeDefaultRoute"] = await NSNumber(value: SharedPreferences.excludeDefaultRoute.get())
        options["autoRouteUseSubRangesByDefault"] = await NSNumber(value: SharedPreferences.autoRouteUseSubRangesByDefault.get())
        options["excludeAPNsRoute"] = await NSNumber(value: SharedPreferences.excludeAPNsRoute.get())

        #if !os(tvOS)
            options["includeAllNetworks"] = await NSNumber(value: SharedPreferences.includeAllNetworks.get())
        #endif

        #if os(tvOS)
            options["commandServerPort"] = await NSNumber(value: SharedPreferences.commandServerPort.get())
            options["commandServerSecret"] = await NSString(string: SharedPreferences.commandServerSecret.get())
        #endif

        return options
    }

    public func fetchProfile() async throws {
        let profileID = await SharedPreferences.selectedProfileID.get()
        if let profile = try await ProfileManager.get(profileID), profile.type == .icloud {
            _ = try await profile.readAsync()
        }
    }

    public func stop() async throws {
        if isMock {
            status = .disconnecting
            try await Task.sleep(nanoseconds: 300_000_000)
            status = .disconnected
            connectedDate = nil
            return
        }
        guard let manager else { return }
        if manager.isOnDemandEnabled {
            if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
                var config = proto.providerConfiguration ?? [:]
                config["wasOnDemandEnabled"] = true
                proto.providerConfiguration = config
            }
            manager.isOnDemandEnabled = false
            try await manager.saveToPreferences()
        }
        do {
            try await Task.detached(priority: .userInitiated) {
                try LibboxNewStandaloneCommandClient()!.serviceClose()
            }.value
        } catch {
            logger.debug("serviceClose error: \(error.localizedDescription)")
        }
        manager.connection.stopVPNTunnel()
    }

    public func restart() async throws {
        try await stop()
        var waitSeconds = 0
        while status != .disconnected {
            try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            waitSeconds += 1
            if waitSeconds >= 5 {
                throw NSError(domain: "ExtensionProfile", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "Restart service timeout")])
            }
        }
        try await start()
    }

    public static func load() async throws -> ExtensionProfile? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if managers.isEmpty {
            return nil
        }
        let profile = ExtensionProfile(managers[0])
        if profile.status == .disconnected {
            schedulePromoteOOMDraft()
        }
        return profile
    }

    public static func install() async throws {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = Variant.applicationName
        let tunnelProtocol = NETunnelProviderProtocol()
        if Variant.useSystemExtension {
            tunnelProtocol.providerBundleIdentifier = AppConfiguration.systemExtensionBundleID
        } else {
            tunnelProtocol.providerBundleIdentifier = AppConfiguration.extensionBundleID
        }
        tunnelProtocol.serverAddress = "sing-box"
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        try await manager.saveToPreferences()
    }

    // MARK: - MITM 配置注入

    /// 向配置 JSON 中注入 MITM 配置字段
    /// - Parameter config: 原始配置 JSON 字符串
    /// - Returns: 注入 MITM 后的配置 JSON 字符串
    static func 注入MITM配置(到 config: String) -> String {
        // 读取 MITM 开关状态（从 App Group UserDefaults）
        guard let 共享默认 = UserDefaults(suiteName: "group.com.singbox.lg") else {
            return config
        }

        let mitmEnabled = 共享默认.bool(forKey: "mitm_enabled")
        guard mitmEnabled else {
            return config
        }

        // 解析配置 JSON
        guard let 配置数据 = config.data(using: .utf8),
              var 配置字典 = try? JSONSerialization.jsonObject(with: 配置数据) as? [String: Any] else {
            logger.error("MITM 配置注入失败：无法解析配置 JSON")
            return config
        }

        // 读取 MITM 设置
        let http2Enabled = 共享默认.bool(forKey: "mitm_http2_enabled")
        let p12Base64 = 共享默认.string(forKey: "mitm_p12_base64") ?? ""

        // 构建 MITM 全局配置（注意：print 是路由规则 mitm 选项的字段，不属于全局配置）
        var mitmConfig: [String: Any] = [
            "enabled": true,
            "http2_enabled": http2Enabled
        ]

        // TLS 解密配置（仅当有证书时才启用）
        if !p12Base64.isEmpty {
            let tlsDecryption: [String: Any] = [
                "enabled": true,
                "key_pair_p12": p12Base64,
                "key_password": ""
            ]
            mitmConfig["tls_decryption"] = tlsDecryption
        } else {
            // 没有证书时不启用 TLS 解密，避免内核报错
            mitmConfig["tls_decryption"] = ["enabled": false]
        }

        // 注入到配置顶层
        配置字典["mitm"] = mitmConfig

        // 注入 MITM 路由触发规则（匹配 HTTP/HTTPS 端口，action=route-options）
        // 没有此规则则 MITM 引擎启动但不处理任何流量
        Self.注入MITM路由规则(到: &配置字典, 抓包启用: 共享默认.bool(forKey: "mitm_capture_enabled"))

        // 序列化回 JSON
        do {
            let 新数据 = try JSONSerialization.data(withJSONObject: 配置字典, options: [.sortedKeys, .prettyPrinted])
            return String(data: 新数据, encoding: .utf8) ?? config
        } catch {
            logger.error("MITM 配置注入失败：序列化错误 \(error.localizedDescription)")
            return config
        }
    }

    /// 向配置的 route.rules 中注入 MITM 触发规则
    /// - Parameters:
    ///   - 配置字典: 配置字典引用
    ///   - 抓包启用: 是否启用抓包日志输出（print 字段）
    private static func 注入MITM路由规则(到 配置字典: inout [String: Any], 抓包启用: Bool) {
        // 构建 MITM 触发规则：匹配 80/443 端口，走 route-options + mitm
        let mitm规则: [String: Any] = [
            "port": [80, 443],
            "action": "route-options",
            "mitm": [
                "enabled": true,
                "print": 抓包启用
            ]
        ]

        // 获取或创建 route 字典
        var route字典 = 配置字典["route"] as? [String: Any] ?? [:]

        // 获取现有规则列表
        var 规则列表 = route字典["rules"] as? [[String: Any]] ?? []

        // 将 MITM 规则插入到最前面（优先匹配）
        规则列表.insert(mitm规则, at: 0)

        // 写回 route 字典
        route字典["rules"] = 规则列表
        配置字典["route"] = route字典

        logger.info("MITM 路由规则已注入（匹配端口 80/443，规则总数：\(规则列表.count)）")
    }
}
