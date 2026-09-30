//
//  工具/圈X脚本引擎.swift
//  sing-box-for-apple 新UI
//
//  圈 X (Quantumult X) 兼容脚本执行引擎
//  使用 JavaScriptCore 框架执行 JS 脚本
//

import Foundation
import JavaScriptCore

// MARK: - 请求/响应对象

@objcMembers
final class 圈X请求: NSObject {
    dynamic var method: String
    dynamic var url: String
    dynamic var headers: [String: String]
    dynamic var body: String?
    dynamic var version: String = "HTTP/1.1"
    init(method: String, url: String, headers: [String: String], body: String? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        super.init()
    }
}

@objcMembers
final class 圈X响应: NSObject {
    dynamic var status: Int
    dynamic var headers: [String: String]
    dynamic var body: String?
    init(status: Int, headers: [String: String], body: String? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
        super.init()
    }
}

struct 圈X执行结果 {
    var 修改后请求: 圈X请求?
    var 修改后响应: 圈X响应?
    var 有伪造响应: Bool
    var 错误: Error?
    var 耗时毫秒: Double
}

// MARK: - 圈X 脚本引擎

final class 圈X脚本引擎 {
    static let 共享 = 圈X脚本引擎()
    private let 上下文队列 = DispatchQueue(label: "com.singbox.quanx.engine")
    private var 上下文池: [JSContext] = []
    private let 池大小 = 3

    private init() {
        for _ in 0..<池大小 {
            if let ctx = 创建JS上下文() { 上下文池.append(ctx) }
        }
    }

    private func 创建JS上下文() -> JSContext? {
        guard let ctx = JSContext() else { return nil }
        ctx.exceptionHandler = { _, 异常 in
            NSLog("[圈X脚本] JS 异常: \(异常?.description ?? "未知")")
        }
        let 日志: @convention(block) (String) -> Void = { 消息 in
            NSLog("[圈X脚本] console: \(消息)")
        }
        let console = JSValue(newObjectIn: ctx)
        console?.setObject(日志, forKeyedSubscript: "log" as NSCopying & NSObjectProtocol)
        ctx.setObject(console, forKeyedSubscript: "console" as NSCopying & NSObjectProtocol)
        return ctx
    }

    private func 获取上下文() -> JSContext? {
        return 上下文队列.sync {
            if let ctx = 上下文池.popLast() { return ctx }
            return 创建JS上下文()
        }
    }

    private func 归还上下文(_ ctx: JSContext) {
        上下文队列.async {
            if self.上下文池.count < self.池大小 { self.上下文池.append(ctx) }
        }
    }

    func 执行请求脚本(脚本代码: String, 请求: 圈X请求, 超时: Double = 10) async -> 圈X执行结果 {
        let 开始 = CFAbsoluteTimeGetCurrent()
        guard let ctx = 获取上下文() else {
            return 圈X执行结果(修改后请求: nil, 修改后响应: nil, 有伪造响应: false, 错误: nil, 耗时毫秒: 0)
        }
        defer { 归还上下文(ctx) }

        ctx.setObject(请求, forKeyedSubscript: "$request" as NSCopying & NSObjectProtocol)
        var 完成请求: 圈X请求? = 请求
        var 完成响应: 圈X响应? = nil
        var 已完成 = false

        let done: @convention(block) (JSValue?) -> Void = { 参数 in
            guard let 参数 = 参数, 参数.isObject else { 已完成 = true; return }
            if let req = 参数.toObjectOf(圈X请求.self) as? 圈X请求 {
                完成请求 = req
            } else if let resp = 参数.toObjectOf(圈X响应.self) as? 圈X响应 {
                完成响应 = resp
            }
            已完成 = true
        }
        ctx.setObject(done, forKeyedSubscript: "$done" as NSCopying & NSObjectProtocol)
        ctx.evaluateScript(脚本代码)

        if let handle = ctx.objectForKeyedSubscript("handleRequest"), !handle.isUndefined {
            handle.call(withArguments: [请求])
        }

        let 等待开始 = Date()
        while !已完成 && Date().timeIntervalSince(等待开始) < 超时 {
            await Task.yield()
        }
        let 耗时 = (CFAbsoluteTimeGetCurrent() - 开始) * 1000
        return 圈X执行结果(修改后请求: 完成请求, 修改后响应: 完成响应, 有伪造响应: 完成响应 != nil, 错误: nil, 耗时毫秒: 耗时)
    }

    func 执行响应脚本(脚本代码: String, 响应: 圈X响应, 请求: 圈X请求, 超时: Double = 10) async -> 圈X执行结果 {
        let 开始 = CFAbsoluteTimeGetCurrent()
        guard let ctx = 获取上下文() else {
            return 圈X执行结果(修改后请求: nil, 修改后响应: nil, 有伪造响应: false, 错误: nil, 耗时毫秒: 0)
        }
        defer { 归还上下文(ctx) }

        ctx.setObject(响应, forKeyedSubscript: "$response" as NSCopying & NSObjectProtocol)
        ctx.setObject(请求, forKeyedSubscript: "$request" as NSCopying & NSObjectProtocol)
        var 完成响应: 圈X响应? = 响应
        var 已完成 = false

        let done: @convention(block) (JSValue?) -> Void = { 参数 in
            guard let 参数 = 参数, 参数.isObject else { 已完成 = true; return }
            if let resp = 参数.toObjectOf(圈X响应.self) as? 圈X响应 {
                完成响应 = resp
            }
            已完成 = true
        }
        ctx.setObject(done, forKeyedSubscript: "$done" as NSCopying & NSObjectProtocol)
        ctx.evaluateScript(脚本代码)

        if let handle = ctx.objectForKeyedSubscript("handleResponse"), !handle.isUndefined {
            handle.call(withArguments: [响应])
        }

        let 等待开始 = Date()
        while !已完成 && Date().timeIntervalSince(等待开始) < 超时 {
            await Task.yield()
        }
        let 耗时 = (CFAbsoluteTimeGetCurrent() - 开始) * 1000
        return 圈X执行结果(修改后请求: nil, 修改后响应: 完成响应, 有伪造响应: false, 错误: nil, 耗时毫秒: 耗时)
    }

    func 测试运行脚本(脚本代码: String, 类型: 圈X脚本类型) async -> [String] {
        var 日志: [String] = []
        let 测试请求 = 圈X请求(method: "GET", url: "https://api.example.com/v1/test",
                              headers: ["Host": "api.example.com", "User-Agent": "sing-box/1.0"])
        let 测试响应 = 圈X响应(status: 200, headers: ["Content-Type": "application/json"],
                            body: "{\"code\":0,\"message\":\"success\"}")
        日志.append("=== 脚本测试开始 ===")
        日志.append("类型: \(类型.显示名称)")
        if 类型 == .请求前 {
            let 结果 = await 执行请求脚本(脚本代码: 脚本代码, 请求: 测试请求, 超时: 5)
            日志.append("执行成功，耗时 \(String(format: "%.1f", 结果.耗时毫秒))ms")
            if let 修改后 = 结果.修改后请求 { 日志.append("修改后 URL: \(修改后.url)") }
        } else {
            let 结果 = await 执行响应脚本(脚本代码: 脚本代码, 响应: 测试响应, 请求: 测试请求, 超时: 5)
            日志.append("执行成功，耗时 \(String(format: "%.1f", 结果.耗时毫秒))ms")
            if let 修改后 = 结果.修改后响应 { 日志.append("状态码: \(修改后.status)") }
        }
        日志.append("=== 测试结束 ===")
        return 日志
    }
}

// MARK: - 预设脚本库

struct 预设脚本库 {
    static let 预设: [圈X脚本条目] = [
        圈X脚本条目(名称: "去除广告", 标签: "remove-ads", 类型: .响应前, 匹配模式: "https?://.*\\.ads\\..*",
                    代码: "function handleResponse(response) {\n    response.status = 200;\n    response.body = '';\n    $done(response);\n}", 需要请求体: true),
        圈X脚本条目(名称: "替换 UA", 标签: "replace-ua", 类型: .请求前, 匹配模式: "https?://.*",
                    代码: "function handleRequest(request) {\n    request.headers['User-Agent'] = 'Mozilla/5.0 (iPhone)';\n    $done(request);\n}"),
        圈X脚本条目(名称: "打印日志", 标签: "log-req", 类型: .请求前, 匹配模式: "https?://api\\..*",
                    代码: "function handleRequest(request) {\n    console.log('API:', request.method, request.url);\n    $done(request);\n}")
    ]
}
