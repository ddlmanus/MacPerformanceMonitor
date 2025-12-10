import Foundation
import SwiftUI

class ProcessViewModel: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var totalMemory: UInt64 = 0
    @Published var usedMemory: UInt64 = 0
    @Published var freeMemory: UInt64 = 0
    
    private var timer: Timer?
    
    var filteredProcesses: [ProcessInfo] {
        if searchText.isEmpty {
            return processes
        }
        return processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var formattedTotalMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }
    
    var formattedUsedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
    }
    
    var memoryUsagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory)
    }
    
    init() {
        refresh()
        startAutoRefresh()
    }
    
    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let processList = ProcessMonitor.getProcessList()
            let memoryInfo = ProcessMonitor.getSystemMemoryInfo()
            
            DispatchQueue.main.async {
                self?.processes = processList
                self?.totalMemory = memoryInfo.total
                self?.usedMemory = memoryInfo.used
                self?.freeMemory = memoryInfo.free
                self?.isLoading = false
            }
        }
    }
    
    func startAutoRefresh(interval: TimeInterval = 5.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func terminateProcess(_ process: ProcessInfo, force: Bool = false, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = ProcessMonitor.terminateProcess(pid: process.pid, force: force)
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.refresh()
                }
                completion(success)
            }
        }
    }
    
    deinit {
        stopAutoRefresh()
    }
}
