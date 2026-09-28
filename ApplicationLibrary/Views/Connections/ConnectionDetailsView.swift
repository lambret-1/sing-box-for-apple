import Foundation
import Libbox
import SwiftUI

public struct ConnectionDetailsView: View {
    private let connection: Connection
    public init(_ connection: Connection) {
        self.connection = connection
    }

    /// 状态颜色
    private var 状态颜色: Color {
        connection.closedAt == nil ? .green : .gray
    }

    public var body: some View {
        FormView {
            // 状态概览
            Section {
                HStack {
                    Circle()
                        .fill(状态颜色)
                        .frame(width: 10, height: 10)
                    Text(connection.closedAt == nil ? "Active" : "Closed")
                        .font(.headline)
                        .foregroundColor(状态颜色)
                    Spacer()
                    Text(connection.createdAt.myFormat)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let closedAt = connection.closedAt {
                    FormTextItem("Duration", LibboxFormatDuration(Int64((closedAt.timeIntervalSince1970 - connection.createdAt.timeIntervalSince1970) * 1000)))
                }
            } header: {
                Text("Status")
            }

            // 流量统计
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Upload", systemImage: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(LibboxFormatBytes(connection.uploadTotal))
                            .font(.title3.monospaced().bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(LibboxFormatBytes(connection.downloadTotal))
                            .font(.title3.monospaced().bold())
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Traffic")
            }

            // 目标信息
            Section {
                FormTextItem("Destination", connection.destination)
                if !connection.domain.isEmpty {
                    FormTextItem("Domain", connection.domain)
                }
                FormTextItem("Network", connection.network.uppercased())
                FormTextItem("IP Version", connection.ipVersion == 4 ? "IPv4" : (connection.ipVersion == 6 ? "IPv6" : "Unknown"))
                if !connection.protocolName.isEmpty {
                    FormTextItem("Protocol", connection.protocolName)
                }
            } header: {
                Text("Destination")
            }

            // 链路信息
            Section {
                FormTextItem("Source", connection.source)
                FormTextItem("Inbound", "\(connection.inboundType) / \(connection.inbound)")
                if !connection.user.isEmpty {
                    FormTextItem("User", connection.user)
                }
                if !connection.fromOutbound.isEmpty {
                    FormTextItem("From Outbound", connection.fromOutbound)
                }
            } header: {
                Text("Inbound")
            }

            // 路由信息
            Section {
                if !connection.rule.isEmpty {
                    FormTextItem("Match Rule", connection.rule)
                }
                FormTextItem("Outbound", "\(connection.outboundType) / \(connection.outbound)")
                if connection.chain.count > 1 {
                    FormTextItem("Chain", connection.chain.reversed().joined(separator: " → "))
                }
            } header: {
                Text("Routing")
            }
        }
        .navigationTitle("Connection Details")
    }
}
