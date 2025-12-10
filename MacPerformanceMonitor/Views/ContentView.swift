import SwiftUI

struct ContentView: View {
    @ObservedObject var processViewModel: ProcessViewModel
    @ObservedObject var portViewModel: PortViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            // 标签页
            tabPicker
            
            Divider()
            
            // 内容区域
            TabView(selection: $selectedTab) {
                ProcessListView(viewModel: processViewModel)
                    .tag(0)
                
                PortListView(viewModel: portViewModel)
                    .tag(1)
            }
            .tabViewStyle(.automatic)
            
            Divider()
            
            // 底部状态栏
            footerView
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "memorychip")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Mac 性能监控")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                processViewModel.refresh()
                portViewModel.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("刷新")
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("退出")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            HStack {
                Image(systemName: "cpu")
                Text("进程")
            }
            .tag(0)
            
            HStack {
                Image(systemName: "network")
                Text("端口")
            }
            .tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var footerView: some View {
        HStack {
            if selectedTab == 0 {
                // 内存使用情况
                HStack(spacing: 4) {
                    Circle()
                        .fill(memoryColor)
                        .frame(width: 8, height: 8)
                    
                    Text("内存: \(processViewModel.formattedUsedMemory) / \(processViewModel.formattedTotalMemory)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 内存使用进度条
                ProgressView(value: processViewModel.memoryUsagePercentage)
                    .frame(width: 80)
                    .tint(memoryColor)
            } else {
                Text("共 \(portViewModel.filteredPorts.count) 个端口")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("仅监听", isOn: $portViewModel.showListeningOnly)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var memoryColor: Color {
        let usage = processViewModel.memoryUsagePercentage
        if usage > 0.9 {
            return .red
        } else if usage > 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    ContentView(processViewModel: ProcessViewModel(), portViewModel: PortViewModel())
}
