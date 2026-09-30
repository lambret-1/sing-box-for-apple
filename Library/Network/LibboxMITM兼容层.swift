//
//  LibboxMITM兼容层.swift
//  sing-box-for-apple
//
//  为 dev-mitm 分支的旧版 Libbox 提供兼容类型定义
//  当使用官方 testing 分支 Libbox 时可移除本文件
//

import Foundation

// MARK: - 连接所有者（旧版 Libbox 缺失）

/// 连接所有者信息（兼容旧版 Libbox）
public final class LibboxConnectionOwner: NSObject {
    /// 用户 ID
    public var userId: Int32 = 0
    /// 用户名
    public var userName: String = ""
    /// 包名
    public var packageName: String = ""

    /// 设置进程路径列表
    public func setProcessPaths(_ paths: LibboxStringIteratorProtocol?) {
        // 旧版 Libbox 不支持进程路径，留空实现
    }
}

// MARK: - 邻居表更新监听器（macOS 专用，旧版 Libbox 缺失）

/// 邻居表更新监听器协议（兼容旧版 Libbox）
@objc public protocol LibboxNeighborUpdateListenerProtocol: AnyObject {
    func updateNeighborTable(_ iterator: LibboxNeighborEntryIteratorProtocol?)
}

/// 邻居条目迭代器协议（兼容旧版 Libbox）
@objc public protocol LibboxNeighborEntryIteratorProtocol: AnyObject {
    func hasNext() -> Bool
    func next() -> LibboxNeighborEntry?
}

/// 邻居条目（兼容旧版 Libbox）
public final class LibboxNeighborEntry: NSObject {
    public var ipAddress: String = ""
    public var macAddress: String = ""
    public var hostName: String = ""
    public var interfaceName: String = ""
    public var expireTime: Int64 = 0
}

// MARK: - 语义化版本比较（旧版 Libbox 缺失）

/// 比较两个语义化版本号
/// - Parameters:
///   - versionA: 版本 A
///   - versionB: 版本 B
/// - Returns: 如果 A > B 返回 true
public func LibboxCompareSemver(_ versionA: String, _ versionB: String) -> Bool {
    let partsA = versionA.split(separator: ".").compactMap { Int($0) }
    let partsB = versionB.split(separator: ".").compactMap { Int($0) }
    let maxLength = max(partsA.count, partsB.count)
    for index in 0..<maxLength {
        let a = index < partsA.count ? partsA[index] : 0
        let b = index < partsB.count ? partsB[index] : 0
        if a != b {
            return a > b
        }
    }
    return false
}
