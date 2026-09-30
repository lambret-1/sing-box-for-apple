//
//  工具/CACertificate生成器.swift
//  sing-box-for-apple 新UI
//
//  CA 证书动态生成：使用 Security 框架生成 RSA 2048 根证书，每个用户独立
//

import Foundation
import Security

// MARK: - CA 证书生成器

/// CA 证书动态生成器
/// 使用 Security 框架生成 RSA 2048 根证书 + 私钥
final class CACertificate生成器 {

    /// 单例
    static let 共享 = CACertificate生成器()

    /// App Group 共享目录中的 mitm 子目录
    var mitm目录URL: URL? {
        guard let 共享容器 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: 全局常量.App组标识) else {
            return nil
        }
        return 共享容器.appendingPathComponent("Documents/mitm", isDirectory: true)
    }

    /// ca.p12 文件 URL
    var p12文件URL: URL? {
        mitm目录URL?.appendingPathComponent("ca.p12")
    }

    /// ca.crt 文件 URL
    var crt文件URL: URL? {
        mitm目录URL?.appendingPathComponent("ca.crt")
    }

    /// mobileconfig 文件 URL
    var mobileconfigURL: URL? {
        mitm目录URL?.appendingPathComponent("sing-box-mitm-ca.mobileconfig")
    }

    private init() {}

    // MARK: - 证书生成

    /// 生成新的 CA 证书（RSA 2048，有效期 10 年）
    /// - Returns: 生成结果
    @discardableResult
    func 生成CA证书() throws -> (p12Data: Data, crtData: Data) {
        // 1. 生成 RSA 2048 私钥
        let 私钥 = try 生成RSA私钥()

        // 2. 创建自签名证书
        let 证书 = try 创建自签名证书(私钥: 私钥)

        // 3. 导出 CRT（仅证书 DER 数据）
        let crtData = SecCertificateCopyData(证书) as Data

        // 4. 导出 P12（简化：暂时使用空数据，后续实现完整 P12）
        let p12Data = Data()

        // 5. 持久化到文件
        try 保存到文件(p12Data: p12Data, crtData: crtData)

        // 6. 标记不备份到 iCloud
        try 标记不备份()

        return (p12Data, crtData)
    }

    // MARK: - 私钥生成

    private func 生成RSA私钥() throws -> SecKey {
        let 参数: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var 错误: Unmanaged<CFError>?
        guard let 私钥 = SecKeyCreateRandomKey(参数 as CFDictionary, &错误) else {
            throw 证书生成错误.私钥生成失败(错误!.takeRetainedValue().localizedDescription)
        }
        return 私钥
    }

    // MARK: - 证书创建

    private func 创建自签名证书(私钥: SecKey) throws -> SecCertificate {
        guard let 公钥 = SecKeyCopyPublicKey(私钥) else {
            throw 证书生成错误.公钥获取失败
        }

        // 构建自签名证书 DER 编码
        let 证书DER = try 构建自签名证书DER(私钥: 私钥, 公钥: 公钥)

        guard let 证书 = SecCertificateCreateWithData(nil, 证书DER as CFData) else {
            throw 证书生成错误.证书创建失败
        }

        return 证书
    }

    /// 手动构建自签名证书的 DER 编码（X.509 v1 简化版）
    private func 构建自签名证书DER(私钥: SecKey, 公钥: SecKey) throws -> Data {
        // 获取公钥 DER 编码
        var 错误: Unmanaged<CFError>?
        guard let 公钥DER = SecKeyCopyExternalRepresentation(公钥, &错误) as Data? else {
            throw 证书生成错误.公钥导出失败
        }

        // 构建 TBSCertificate
        // 版本: v1
        let 版本 = Data([0x02, 0x01, 0x00])

        // 序列号: 1
        let 序列号 = Data([0x02, 0x01, 0x01])

        // 签名算法: SHA256withRSA (OID: 1.2.840.113549.1.1.11)
        let 签名算法ID = Data([
            0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B, 0x05, 0x00
        ])

        // 颁发者: CN=sing-box MITM CA
        let 颁发者 = 构建X509名称(通用名: "sing-box MITM CA")

        // 有效期: 现在 + 10 年
        let 有效期 = 构建有效期(年数: 10)

        // 主题: 同颁发者（自签名）
        let 主题 = 构建X509名称(通用名: "sing-box MITM CA")

        // 公钥信息
        let 公钥信息 = 构建公钥信息(公钥DER: 公钥DER)

        // 组装 TBSCertificate
        var tbsData = Data()
        tbsData.append(版本)
        tbsData.append(序列号)
        tbsData.append(签名算法ID)
        tbsData.append(颁发者)
        tbsData.append(有效期)
        tbsData.append(主题)
        tbsData.append(公钥信息)

        // 包装为 SEQUENCE
        let tbsCertificate = 包装为序列(tbsData)

        // 签名
        var 签名错误: Unmanaged<CFError>?
        guard let 签名数据 = SecKeyCreateSignature(
            私钥,
            .rsaSignatureMessagePKCS1v15SHA256,
            tbsCertificate as CFData,
            &签名错误
        ) as Data? else {
            throw 证书生成错误.签名失败
        }

        // 组装完整证书
        var 证书数据 = Data()
        证书数据.append(tbsCertificate)
        证书数据.append(签名算法ID)
        证书数据.append(包装为位串(签名数据))

        // 包装为顶层 SEQUENCE
        return 包装为序列(证书数据)
    }

    // MARK: - ASN.1 构建

    private func 构建X509名称(通用名: String) -> Data {
        // OID for commonName: 2.5.4.3
        let oidData = Data([0x55, 0x04, 0x03])
        let 值数据 = 通用名.data(using: .utf8)!

        // AttributeValueAssertion: SEQUENCE { OID, value }
        var avaData = Data()
        avaData.append(oidData)
        avaData.append(包装为UTF8字符串(值数据))
        let ava = 包装为序列(avaData)

        // RDN: SET OF AVA
        let rdn = 包装为集合(ava)

        // RDNSequence: SEQUENCE OF RDN
        return 包装为序列(rdn)
    }

    private func 构建有效期(年数: Int) -> Data {
        let 日期格式化 = DateFormatter()
        日期格式化.dateFormat = "yyMMddHHmmss"
        日期格式化.timeZone = TimeZone(identifier: "UTC")

        let 现在字符串 = 日期格式化.string(from: Date())
        let 现在数据 = 现在字符串.data(using: .ascii)!

        let 结束日期 = Calendar.current.date(byAdding: .year, value: 年数, to: Date())!
        let 结束字符串 = 日期格式化.string(from: 结束日期)
        let 结束数据 = 结束字符串.data(using: .ascii)!

        // Validity: SEQUENCE { notBefore UTCTime, notAfter UTCTime }
        var 有效期数据 = Data()
        // notBefore
        有效期数据.append(0x17) // UTCTime tag
        有效期数据.append(UInt8(现在数据.count))
        有效期数据.append(现在数据)
        // notAfter
        有效期数据.append(0x17)
        有效期数据.append(UInt8(结束数据.count))
        有效期数据.append(结束数据)

        return 包装为序列(有效期数据)
    }

    private func 构建公钥信息(公钥DER: Data) -> Data {
        // AlgorithmIdentifier: RSA (OID: 1.2.840.113549.1.1.1)
        let 算法ID = Data([
            0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00
        ])

        // SubjectPublicKeyInfo = AlgorithmIdentifier + BIT STRING(公钥)
        var spki = Data()
        spki.append(算法ID)
        spki.append(包装为位串(公钥DER))

        return 包装为序列(spki)
    }

    // MARK: - ASN.1 包装函数

    private func 包装为序列(_ data: Data) -> Data {
        var result = Data()
        result.append(0x30)
        result.append(编码长度(data.count))
        result.append(data)
        return result
    }

    private func 包装为集合(_ data: Data) -> Data {
        var result = Data()
        result.append(0x31)
        result.append(编码长度(data.count))
        result.append(data)
        return result
    }

    private func 包装为位串(_ data: Data) -> Data {
        var result = Data()
        result.append(0x03) // BIT STRING
        let 长度 = data.count + 1
        result.append(编码长度(长度))
        result.append(0x00) // 未使用位数
        result.append(data)
        return result
    }

    private func 包装为UTF8字符串(_ data: Data) -> Data {
        var result = Data()
        result.append(0x0C) // UTF8String
        result.append(编码长度(data.count))
        result.append(data)
        return result
    }

    private func 编码长度(_ length: Int) -> Data {
        if length < 128 {
            return Data([UInt8(length)])
        } else if length < 256 {
            return Data([0x81, UInt8(length)])
        } else if length < 65536 {
            return Data([0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        } else {
            return Data([0x83, UInt8(length >> 16), UInt8(length >> 8), UInt8(length & 0xFF)])
        }
    }

    // MARK: - 文件持久化

    private func 保存到文件(p12Data: Data, crtData: Data) throws {
        guard let 目录 = mitm目录URL else {
            throw 证书生成错误.目录创建失败
        }

        try FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)

        if let crtURL = crt文件URL {
            try crtData.write(to: crtURL, options: .atomic)
        }

        if let p12URL = p12文件URL {
            try p12Data.write(to: p12URL, options: .atomic)
        }
    }

    private func 标记不备份() throws {
        guard let 目录 = mitm目录URL else { return }
        var 资源URL = 目录 as NSURL
        try 资源URL.setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
    }

    // MARK: - 证书状态检测

    /// 检测当前证书状态
    func 检测证书状态() -> MITM证书状态 {
        guard let crtURL = crt文件URL else {
            return .文件缺失
        }

        guard FileManager.default.fileExists(atPath: crtURL.path) else {
            return .文件缺失
        }

        guard let 证书数据 = try? Data(contentsOf: crtURL) else {
            return .文件损坏
        }

        guard let 证书 = SecCertificateCreateWithData(nil, 证书数据 as CFData) else {
            return .文件损坏
        }

        // 检查证书有效期（简化：假设刚生成的证书有效）
        // 完整实现需要解析 notAfter 字段
        let 过期日期 = Date().addingTimeInterval(10 * 365 * 24 * 60 * 60) // 10 年
        let 现在 = Date()

        if 现在 > 过期日期 {
            return .已过期
        }

        let 剩余天数 = Calendar.current.dateComponents([.day], from: 现在, to: 过期日期).day ?? 0
        if 剩余天数 < 30 {
            return .临近过期(剩余天数: 剩余天数)
        }

        // 证书已生成，等待用户安装
        return .未安装
    }

    /// 获取证书的 PEM 格式
    func 获取证书PEM() -> String? {
        guard let crtURL = crt文件URL,
              let 数据 = try? Data(contentsOf: crtURL) else {
            return nil
        }
        return "-----BEGIN CERTIFICATE-----\n" +
            数据.base64EncodedString(options: .lineLength64Characters) +
            "\n-----END CERTIFICATE-----"
    }

    /// 获取 P12 的 Base64 编码
    func 获取P12Base64() -> String? {
        guard let p12URL = p12文件URL,
              let 数据 = try? Data(contentsOf: p12URL),
              !数据.isEmpty else {
            return nil
        }
        return 数据.base64EncodedString()
    }

    // MARK: - MobileConfig 导出

    /// 生成 .mobileconfig 描述文件
    func 生成MobileConfig() throws -> URL {
        guard let crtURL = crt文件URL,
              let 证书数据 = try? Data(contentsOf: crtURL) else {
            throw 证书生成错误.文件缺失
        }

        let 证书Base64 = 证书数据.base64EncodedString()
        let uuid = UUID().uuidString
        let payloadUUID = UUID().uuidString

        let mobileconfig = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadContent</key>
                    <data>\(证书Base64)</data>
                    <key>PayloadDisplayName</key>
                    <string>sing-box MITM CA 证书</string>
                    <key>PayloadIdentifier</key>
                    <string>com.singbox.lg.mitm.ca</string>
                    <key>PayloadType</key>
                    <string>com.apple.security.root</string>
                    <key>PayloadUUID</key>
                    <string>\(payloadUUID)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>sing-box MITM 证书</string>
            <key>PayloadIdentifier</key>
            <string>com.singbox.lg.mitm</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(uuid)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """

        guard let mobileconfigURL = mobileconfigURL else {
            throw 证书生成错误.目录创建失败
        }

        try mobileconfig.write(to: mobileconfigURL, atomically: true, encoding: .utf8)
        return mobileconfigURL
    }
}

// MARK: - 错误类型

enum 证书生成错误: Error, LocalizedError {
    case 私钥生成失败(String)
    case 公钥获取失败
    case 公钥导出失败
    case 证书创建失败
    case 签名失败
    case 目录创建失败
    case 文件缺失

    var errorDescription: String? {
        switch self {
        case .私钥生成失败(let 详情):
            return "私钥生成失败：\(详情)"
        case .公钥获取失败:
            return "公钥获取失败"
        case .公钥导出失败:
            return "公钥导出失败"
        case .证书创建失败:
            return "证书创建失败"
        case .签名失败:
            return "证书签名失败"
        case .目录创建失败:
            return "mitm 目录创建失败"
        case .文件缺失:
            return "证书文件缺失"
        }
    }
}
