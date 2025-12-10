import SwiftUI

struct PortListView: View {
    @ObservedObject var viewModel: PortViewModel
    @State private var showingReleaseAlert = false
    @State private var portToRelease: PortInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
            
            Divider()
            
            // 端口列表
            if viewModel.isLoading && viewModel.ports.isEmpty {
                loadingView
            } else if viewModel.filteredPorts.isEmpty {
                emptyView
            } else {
                portList
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索端口或进程...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("未找到端口")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var portList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredPorts) { port in
                    PortRowView(portInfo: port) {
                        portToRelease = port
                        showingReleaseAlert = true
                    }
                    
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .alert("确认释放端口", isPresented: $showingReleaseAlert, presenting: portToRelease) { port in
            Button("取消", role: .cancel) { }
            Button("释放", role: .destructive) {
                viewModel.releasePort(port) { _ in }
            }
        } message: { port in
            Text("确定要释放端口 \(port.port) 吗？\n\n这将终止进程 \"\(port.processName)\" (PID: \(port.pid))。")
        }
    }
}

struct PortRowView: View {
    let portInfo: PortInfo
    let onRelease: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 端口图标
            ZStack {
                Circle()
                    .fill(portColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "network")
                    .font(.system(size: 14))
                    .foregroundColor(portColor)
            }
            
            // 端口信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(":\(portInfo.port)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    
                    // 协议标签
                    Text(portInfo.protocolType)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(portInfo.protocolType == "TCP" ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .foregroundColor(portInfo.protocolType == "TCP" ? .blue : .purple)
                        .cornerRadius(4)
                    
                    // 状态标签
                    Text(portInfo.state)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(stateColor.opacity(0.15))
                        .foregroundColor(stateColor)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 4) {
                    Text(portInfo.processName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("(PID: \(portInfo.pid))")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            // 释放按钮
            Button(action: onRelease) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(isHovering ? 1 : 0.6))
            }
            .buttonStyle(.borderless)
            .help("释放端口")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var portColor: Color {
        // 常用端口用不同颜色
        switch portInfo.port {
        case 80, 443: return .green
        case 22: return .orange
        case 3000...9999: return .blue
        default: return .secondary
        }
    }
    
    private var stateColor: Color {
        switch portInfo.state.uppercased() {
        case "LISTEN": return .green
        case "ESTABLISHED": return .blue
        case "TIME_WAIT": return .orange
        case "CLOSE_WAIT": return .red
        default: return .secondary
        }
    }
}

#Preview {
    PortListView(viewModel: PortViewModel())
}
