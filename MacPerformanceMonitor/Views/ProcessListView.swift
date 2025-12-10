import SwiftUI

struct ProcessListView: View {
    @ObservedObject var viewModel: ProcessViewModel
    @State private var showingKillAlert = false
    @State private var processToKill: ProcessInfo?
    @State private var killResult: Bool?
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
            
            Divider()
            
            // 进程列表
            if viewModel.isLoading && viewModel.processes.isEmpty {
                loadingView
            } else if viewModel.filteredProcesses.isEmpty {
                emptyView
            } else {
                processList
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索进程...", text: $viewModel.searchText)
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
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("未找到进程")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var processList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredProcesses) { process in
                    ProcessRowView(process: process) {
                        processToKill = process
                        showingKillAlert = true
                    }
                    
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .alert("确认终止进程", isPresented: $showingKillAlert, presenting: processToKill) { process in
            Button("取消", role: .cancel) { }
            Button("终止", role: .destructive) {
                viewModel.terminateProcess(process, force: true) { success in
                    killResult = success
                }
            }
        } message: { process in
            Text("确定要终止进程 \"\(process.name)\" (PID: \(process.pid)) 吗？\n\n⚠️ 未保存的数据可能会丢失。")
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessInfo
    let onKill: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 进程图标
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            // 进程信息
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("PID: \(process.pid)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("CPU: \(process.formattedCPU)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 内存使用
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(memoryColor)
                
                // 内存条
                ProgressView(value: min(Double(process.memoryUsage) / (4 * 1024 * 1024 * 1024), 1.0))
                    .frame(width: 50)
                    .tint(memoryColor)
            }
            
            // 终止按钮
            Button(action: onKill) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(isHovering ? 1 : 0.6))
            }
            .buttonStyle(.borderless)
            .help("终止进程")
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
    
    private var memoryColor: Color {
        let memoryGB = Double(process.memoryUsage) / (1024 * 1024 * 1024)
        if memoryGB > 2 {
            return .red
        } else if memoryGB > 1 {
            return .orange
        } else {
            return .primary
        }
    }
}

#Preview {
    ProcessListView(viewModel: ProcessViewModel())
}
