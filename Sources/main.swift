import SwiftUI
import AppKit

// MARK: - Models

struct AppProcessInfo: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let memoryUsage: UInt64
    let cpuUsage: Double
    let user: String
    
    var formattedMemory: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(memoryUsage))
    }
    
    var formattedCPU: String {
        return String(format: "%.1f%%", cpuUsage)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
    
    static func == (lhs: AppProcessInfo, rhs: AppProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let pid: Int32
    let processName: String
    let protocolType: String
    let state: String
    let localAddress: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(port)
        hasher.combine(pid)
    }
    
    static func == (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.port == rhs.port && lhs.pid == rhs.pid
    }
}

struct RunningApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let pid: pid_t
    let isActive: Bool
    let memoryUsage: UInt64  // 内存占用 (bytes)
    let cpuUsage: Double     // CPU 占用率
    
    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
    
    var formattedCPU: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
    
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.pid == rhs.pid
    }
}

struct CacheInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let icon: String
    let category: CacheCategory
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    enum CacheCategory: String {
        case browser = "浏览器"
        case system = "系统"
        case app = "应用"
    }
}

struct DiskInfo {
    let totalSpace: UInt64
    let usedSpace: UInt64
    let freeSpace: UInt64
    
    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: Int64(totalSpace), countStyle: .file) }
    var formattedUsed: String { ByteCountFormatter.string(fromByteCount: Int64(usedSpace), countStyle: .file) }
    var formattedFree: String { ByteCountFormatter.string(fromByteCount: Int64(freeSpace), countStyle: .file) }
    var usagePercentage: Double { totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0 }
}

struct CacheFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let isDirectory: Bool
    let modificationDate: Date?
    
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) }
    var formattedDate: String {
        guard let date = modificationDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Services

class ShellExecutor {
    static func execute(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.environment = Foundation.ProcessInfo.processInfo.environment
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ("", error.localizedDescription, -1)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        return (output, errorOutput, task.terminationStatus)
    }
    
    static func killProcess(pid: Int32, force: Bool = false) -> Bool {
        let signal = force ? "-9" : "-15"
        let result = execute("kill \(signal) \(pid)")
        return result.exitCode == 0
    }
}

class ProcessMonitor {
    static func getProcessList() -> [AppProcessInfo] {
        let command = "ps -axo pid,user,%cpu,rss,comm | tail -n +2 | sort -k4 -rn | head -100"
        let result = ShellExecutor.execute(command)
        
        guard result.exitCode == 0 else { return [] }
        return parseProcessOutput(result.output)
    }
    
    private static func parseProcessOutput(_ output: String) -> [AppProcessInfo] {
        var processes: [AppProcessInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard components.count >= 5 else { continue }
            
            guard let pid = Int32(components[0]),
                  let cpuUsage = Double(components[2]),
                  let rssKB = UInt64(components[3]) else { continue }
            
            let user = String(components[1])
            let name = String(components[4])
            let appName = (name as NSString).lastPathComponent
            let memoryBytes = rssKB * 1024
            
            guard memoryBytes > 0 else { continue }
            
            let process = AppProcessInfo(
                pid: pid,
                name: appName,
                memoryUsage: memoryBytes,
                cpuUsage: cpuUsage,
                user: user
            )
            processes.append(process)
        }
        return processes
    }
    
    static func getSystemMemoryInfo() -> (total: UInt64, used: UInt64, free: UInt64) {
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        
        let result = ShellExecutor.execute("vm_stat")
        guard result.exitCode == 0 else { return (totalMemory, 0, totalMemory) }
        
        let pageSize: UInt64 = 4096
        var freePages: UInt64 = 0, activePages: UInt64 = 0, wiredPages: UInt64 = 0, compressedPages: UInt64 = 0, inactivePages: UInt64 = 0
        
        for line in result.output.components(separatedBy: "\n") {
            if line.contains("Pages free") { freePages = extractPageCount(from: line) }
            else if line.contains("Pages active") { activePages = extractPageCount(from: line) }
            else if line.contains("Pages inactive") { inactivePages = extractPageCount(from: line) }
            else if line.contains("Pages wired") { wiredPages = extractPageCount(from: line) }
            else if line.contains("Pages occupied by compressor") { compressedPages = extractPageCount(from: line) }
        }
        
        let usedMemory = (activePages + wiredPages + compressedPages) * pageSize
        let freeMemory = (freePages + inactivePages) * pageSize
        return (totalMemory, usedMemory, freeMemory)
    }
    
    private static func extractPageCount(from line: String) -> UInt64 {
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return 0 }
        let valueStr = components[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
        return UInt64(valueStr) ?? 0
    }
    
    static func terminateProcess(pid: Int32, force: Bool = false) -> Bool {
        return ShellExecutor.killProcess(pid: pid, force: force)
    }
}

class PortMonitor {
    static func getPortList() -> [PortInfo] {
        // 使用 lsof 获取所有网络连接
        let command = "lsof -i -P -n 2>/dev/null"
        let result = ShellExecutor.execute(command)
        guard !result.output.isEmpty else { return [] }
        return parsePortOutput(result.output)
    }
    
    private static func parsePortOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        var seenPorts: Set<String> = []
        
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // 跳过表头
            if trimmed.hasPrefix("COMMAND") { continue }
            
            // 只处理 LISTEN 和 ESTABLISHED 状态
            guard trimmed.contains("LISTEN") || trimmed.contains("ESTABLISHED") else { continue }
            
            // 按空格分割
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }
            
            let processName = String(components[0])
            guard let pid = Int32(components[1]) else { continue }
            
            // 最后一个字段是 NAME，可能格式如：*:8081 (LISTEN) 或 127.0.0.1:8081 (LISTEN)
            // 找到包含端口信息的字段
            var nameField = ""
            var stateField = ""
            
            // 从后往前找，找到包含 : 的字段作为地址，包含括号的作为状态
            for i in stride(from: components.count - 1, through: 0, by: -1) {
                let comp = String(components[i])
                if comp.hasPrefix("(") && comp.hasSuffix(")") {
                    stateField = comp.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                } else if comp.contains(":") && nameField.isEmpty {
                    nameField = comp
                }
            }
            
            guard !nameField.isEmpty else { continue }
            
            // 解析端口号
            var port = 0
            var localAddress = nameField
            
            // 处理 IPv6 格式，如 [::1]:8080 或 *:8080
            if nameField.contains("]:") {
                // IPv6 格式
                if let colonRange = nameField.range(of: "]:", options: .backwards) {
                    let portStr = String(nameField[colonRange.upperBound...])
                    port = Int(portStr) ?? 0
                }
            } else if nameField.contains(":") {
                // IPv4 格式或 *:port
                let parts = nameField.components(separatedBy: ":")
                if let lastPart = parts.last, let portNum = Int(lastPart) {
                    port = portNum
                }
            }
            
            guard port > 0 else { continue }
            
            // 确定协议类型
            let protocolType = trimmed.contains("TCP") ? "TCP" : (trimmed.contains("UDP") ? "UDP" : "TCP")
            
            // 去重
            let uniqueKey = "\(port)-\(pid)-\(stateField)"
            guard !seenPorts.contains(uniqueKey) else { continue }
            seenPorts.insert(uniqueKey)
            
            ports.append(PortInfo(
                port: port,
                pid: pid,
                processName: processName,
                protocolType: protocolType,
                state: stateField,
                localAddress: localAddress
            ))
        }
        
        return ports.sorted { $0.port < $1.port }
    }
    
    static func releasePort(pid: Int32, force: Bool = false) -> Bool {
        return ShellExecutor.killProcess(pid: pid, force: force)
    }
}

class AppMonitor {
    static func getRunningApps() -> [RunningApp] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // 获取所有进程的资源占用情况
        let resourceUsage = getProcessResourceUsage()
        
        return runningApps.compactMap { app -> RunningApp? in
            // 只显示普通应用（有界面的）
            guard app.activationPolicy == .regular else { return nil }
            guard let name = app.localizedName else { return nil }
            
            let pid = app.processIdentifier
            let usage = resourceUsage[pid] ?? (memory: 0, cpu: 0.0)
            
            return RunningApp(
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                icon: app.icon,
                pid: pid,
                isActive: app.isActive,
                memoryUsage: usage.memory,
                cpuUsage: usage.cpu
            )
        }.sorted { $0.memoryUsage > $1.memoryUsage }  // 按内存占用排序
    }
    
    private static func getProcessResourceUsage() -> [pid_t: (memory: UInt64, cpu: Double)] {
        var result: [pid_t: (memory: UInt64, cpu: Double)] = [:]
        
        // 使用 ps 命令获取所有进程的 CPU 和内存占用
        let command = "ps -axo pid,%cpu,rss"
        let output = ShellExecutor.execute(command)
        
        guard output.exitCode == 0 else { return result }
        
        let lines = output.output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("PID") else { continue }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 3 else { continue }
            
            guard let pid = pid_t(components[0]),
                  let cpu = Double(components[1]),
                  let rssKB = UInt64(components[2]) else { continue }
            
            result[pid] = (memory: rssKB * 1024, cpu: cpu)
        }
        
        return result
    }
    
    static func terminateApp(pid: pid_t, force: Bool = false) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        if force {
            return app.forceTerminate()
        } else {
            return app.terminate()
        }
    }
    
    static func activateApp(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        app.activate(options: [.activateIgnoringOtherApps])
    }
}

class CacheMonitor {
    static let cacheLocations: [(name: String, path: String, icon: String, category: CacheInfo.CacheCategory)] = [
        // 浏览器缓存
        ("Chrome 浏览器缓存", "~/Library/Caches/Google/Chrome", "globe", .browser),
        ("Safari 浏览器缓存", "~/Library/Caches/com.apple.Safari", "safari", .browser),
        ("Firefox 浏览器缓存", "~/Library/Caches/Firefox", "flame", .browser),
        ("Edge 浏览器缓存", "~/Library/Caches/Microsoft Edge", "globe", .browser),
        
        // 系统缓存
        ("系统缓存", "~/Library/Caches", "gear", .system),
        ("系统日志", "~/Library/Logs", "doc.text", .system),
        ("临时文件", "/tmp", "trash", .system),
        
        // 应用缓存
        ("Xcode 缓存", "~/Library/Developer/Xcode/DerivedData", "hammer", .app),
        ("npm 缓存", "~/.npm/_cacache", "shippingbox", .app),
        ("Homebrew 缓存", "~/Library/Caches/Homebrew", "cup.and.saucer", .app),
    ]
    
    static func scanCaches() -> [CacheInfo] {
        var caches: [CacheInfo] = []
        
        for location in cacheLocations {
            let expandedPath = NSString(string: location.path).expandingTildeInPath
            let size = calculateDirectorySize(path: expandedPath)
            
            if size > 0 {
                caches.append(CacheInfo(
                    name: location.name,
                    path: expandedPath,
                    size: size,
                    icon: location.icon,
                    category: location.category
                ))
            }
        }
        
        return caches.sorted { $0.size > $1.size }
    }
    
    static func calculateDirectorySize(path: String) -> UInt64 {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return 0 }
        
        var totalSize: UInt64 = 0
        
        if let enumerator = fileManager.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let filePath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let fileSize = attrs[.size] as? UInt64 {
                    totalSize += fileSize
                }
            }
        }
        
        return totalSize
    }
    
    static func cleanCache(at path: String) -> (success: Bool, freedSize: UInt64) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return (false, 0) }
        
        var freedSize: UInt64 = 0
        var deletedCount = 0
        var failedCount = 0
        
        // 获取目录内容
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return (false, 0)
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            
            // 跳过重要的系统文件和目录
            let skipItems = [".", "..", ".DS_Store", ".Trash", ".localized"]
            if skipItems.contains(item) { continue }
            
            // 计算文件/目录大小
            var itemSize: UInt64 = 0
            var isDir: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    // 递归计算目录大小
                    itemSize = calculateDirectorySize(path: itemPath)
                } else {
                    if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
                       let size = attrs[.size] as? UInt64 {
                        itemSize = size
                    }
                }
            }
            
            // 尝试删除
            do {
                try fileManager.removeItem(atPath: itemPath)
                freedSize += itemSize
                deletedCount += 1
            } catch {
                // 记录失败但继续处理其他文件
                failedCount += 1
                // print("无法删除: \(itemPath) - \(error.localizedDescription)")
            }
        }
        
        // 如果至少删除了一些文件，就算成功
        return (deletedCount > 0, freedSize)
    }
    
    static func getTotalCacheSize() -> UInt64 {
        return scanCaches().reduce(0) { $0 + $1.size }
    }
    
    static func getDiskInfo() -> DiskInfo {
        let fileURL = URL(fileURLWithPath: "/")
        if let values = try? fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
           let total = values.volumeTotalCapacity,
           let free = values.volumeAvailableCapacityForImportantUsage {
            return DiskInfo(totalSpace: UInt64(total), usedSpace: UInt64(total) - UInt64(free), freeSpace: UInt64(free))
        }
        return DiskInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
    }
    
    static func getCacheFiles(at path: String, limit: Int = 100) -> [CacheFileInfo] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        
        var files: [CacheFileInfo] = []
        for item in contents.prefix(limit) {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) else { continue }
            
            var size: UInt64 = 0
            var modDate: Date?
            
            if let attrs = try? fileManager.attributesOfItem(atPath: itemPath) {
                size = isDir.boolValue ? calculateDirectorySize(path: itemPath) : (attrs[.size] as? UInt64 ?? 0)
                modDate = attrs[.modificationDate] as? Date
            }
            
            files.append(CacheFileInfo(name: item, path: itemPath, size: size, isDirectory: isDir.boolValue, modificationDate: modDate))
        }
        
        return files.sorted { $0.size > $1.size }
    }
}

// MARK: - ViewModels

class ProcessViewModel: ObservableObject {
    @Published var processes: [AppProcessInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var totalMemory: UInt64 = 0
    @Published var usedMemory: UInt64 = 0
    @Published var freeMemory: UInt64 = 0
    
    private var timer: Timer?
    
    var filteredProcesses: [AppProcessInfo] {
        if searchText.isEmpty { return processes }
        return processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var formattedTotalMemory: String { ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory) }
    var formattedUsedMemory: String { ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory) }
    var memoryUsagePercentage: Double { totalMemory > 0 ? Double(usedMemory) / Double(totalMemory) : 0 }
    
    init() { refresh(); startAutoRefresh() }
    
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
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
    }
    
    func terminateProcess(_ process: AppProcessInfo, force: Bool = false, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = ProcessMonitor.terminateProcess(pid: process.pid, force: force)
            DispatchQueue.main.async { [weak self] in
                if success { self?.refresh() }
                completion(success)
            }
        }
    }
    
    deinit { timer?.invalidate() }
}

class PortViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var showListeningOnly = true
    
    private var timer: Timer?
    
    var filteredPorts: [PortInfo] {
        var result = ports
        if showListeningOnly { result = result.filter { $0.state.uppercased() == "LISTEN" } }
        if !searchText.isEmpty {
            result = result.filter { $0.processName.localizedCaseInsensitiveContains(searchText) || String($0.port).contains(searchText) }
        }
        return result
    }
    
    init() { refresh(); startAutoRefresh() }
    
    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let portList = PortMonitor.getPortList()
            DispatchQueue.main.async { self?.ports = portList; self?.isLoading = false }
        }
    }
    
    func startAutoRefresh(interval: TimeInterval = 10.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
    }
    
    func releasePort(_ portInfo: PortInfo, force: Bool = true, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = PortMonitor.releasePort(pid: portInfo.pid, force: force)
            DispatchQueue.main.async { [weak self] in
                if success { self?.refresh() }
                completion(success)
            }
        }
    }
    
    deinit { timer?.invalidate() }
}

class AppViewModel: ObservableObject {
    @Published var apps: [RunningApp] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    
    private var timer: Timer?
    
    var filteredApps: [RunningApp] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    init() { refresh(); startAutoRefresh() }
    
    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let appList = AppMonitor.getRunningApps()
            DispatchQueue.main.async {
                self?.apps = appList
                self?.isLoading = false
            }
        }
    }
    
    func startAutoRefresh(interval: TimeInterval = 3.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
    }
    
    func terminateApp(_ app: RunningApp, force: Bool = false, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = AppMonitor.terminateApp(pid: app.pid, force: force)
            DispatchQueue.main.async { [weak self] in
                // 等待一小段时间让应用关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refresh()
                }
                completion(success)
            }
        }
    }
    
    func activateApp(_ app: RunningApp) {
        AppMonitor.activateApp(pid: app.pid)
    }
    
    deinit { timer?.invalidate() }
}

class CacheViewModel: ObservableObject {
    @Published var caches: [CacheInfo] = []
    @Published var isLoading = false
    @Published var isClearing = false
    @Published var totalSize: UInt64 = 0
    @Published var lastCleanedSize: UInt64 = 0
    @Published var showCleanResult = false
    @Published var diskInfo: DiskInfo = DiskInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
    @Published var selectedCacheFiles: [CacheFileInfo] = []
    @Published var selectedCache: CacheInfo?
    @Published var showCacheDetails = false
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    var formattedCleanedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(lastCleanedSize), countStyle: .file)
    }
    
    init() { refresh() }
    
    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cacheList = CacheMonitor.scanCaches()
            let total = cacheList.reduce(0) { $0 + $1.size }
            let disk = CacheMonitor.getDiskInfo()
            DispatchQueue.main.async {
                self?.caches = cacheList
                self?.totalSize = total
                self?.diskInfo = disk
                self?.isLoading = false
            }
        }
    }
    
    func loadCacheDetails(_ cache: CacheInfo) {
        selectedCache = cache
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = CacheMonitor.getCacheFiles(at: cache.path)
            DispatchQueue.main.async {
                self?.selectedCacheFiles = files
                self?.showCacheDetails = true
            }
        }
    }
    
    func cleanCache(_ cache: CacheInfo, completion: @escaping (Bool, UInt64) -> Void) {
        isClearing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CacheMonitor.cleanCache(at: cache.path)
            DispatchQueue.main.async {
                self?.isClearing = false
                if result.success {
                    self?.lastCleanedSize = result.freedSize
                    self?.showCleanResult = true
                    self?.refresh()
                }
                completion(result.success, result.freedSize)
            }
        }
    }
    
    func cleanAllCaches(completion: @escaping (UInt64) -> Void) {
        isClearing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var totalFreed: UInt64 = 0
            let caches = self?.caches ?? []
            
            for cache in caches {
                let result = CacheMonitor.cleanCache(at: cache.path)
                if result.success {
                    totalFreed += result.freedSize
                }
            }
            
            DispatchQueue.main.async {
                self?.isClearing = false
                self?.lastCleanedSize = totalFreed
                self?.showCleanResult = true
                self?.refresh()
                completion(totalFreed)
            }
        }
    }
}

// MARK: - Views

struct AppRowView: View {
    let app: RunningApp
    let onQuit: () -> Void
    let onActivate: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            
            // 应用信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    if app.isActive {
                        Text("活跃")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("PID: \(app.pid)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("CPU: \(app.formattedCPU)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 内存占用
            VStack(alignment: .trailing, spacing: 2) {
                Text(app.formattedMemory)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(memoryColor)
                ProgressView(value: min(Double(app.memoryUsage) / (2 * 1024 * 1024 * 1024), 1.0))
                    .frame(width: 50)
                    .tint(memoryColor)
            }
            
            // 操作按钮
            HStack(spacing: 6) {
                Button(action: onActivate) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(isHovering ? 1 : 0.6))
                }
                .buttonStyle(.borderless)
                .help("激活应用")
                
                Button(action: onQuit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(isHovering ? 1 : 0.6))
                }
                .buttonStyle(.borderless)
                .help("退出应用")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { isHovering = $0 }
    }
    
    private var memoryColor: Color {
        let memoryGB = Double(app.memoryUsage) / (1024 * 1024 * 1024)
        if memoryGB > 1 { return .red }
        else if memoryGB > 0.5 { return .orange }
        else { return .primary }
    }
}

struct AppListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingQuitAlert = false
    @State private var appToQuit: RunningApp?
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索应用...", text: $viewModel.searchText).textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.borderless)
                }
            }
            .padding(8).background(Color(NSColor.textBackgroundColor)).cornerRadius(8).padding(.horizontal, 12).padding(.vertical, 8)
            
            Divider()
            
            if viewModel.isLoading && viewModel.apps.isEmpty {
                VStack { ProgressView().scaleEffect(0.8); Text("加载中...").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredApps.isEmpty {
                VStack(spacing: 8) { Image(systemName: "app.badge.checkmark").font(.largeTitle).foregroundColor(.secondary); Text("没有运行的应用").font(.subheadline).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredApps) { app in
                            AppRowView(
                                app: app,
                                onQuit: { appToQuit = app; showingQuitAlert = true },
                                onActivate: { viewModel.activateApp(app) }
                            )
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .alert("确认退出应用", isPresented: $showingQuitAlert, presenting: appToQuit) { app in
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) { viewModel.terminateApp(app, force: false) { _ in } }
            Button("强制退出", role: .destructive) { viewModel.terminateApp(app, force: true) { _ in } }
        } message: { app in
            Text("确定要退出 \"\(app.name)\" 吗？\n\n⚠️ 未保存的数据可能会丢失。")
        }
    }
}

struct ProcessRowView: View {
    let process: AppProcessInfo
    let onKill: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill").font(.title2).foregroundColor(.blue).frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 8) {
                    Text("PID: \(process.pid)").font(.caption2).foregroundColor(.secondary)
                    Text("CPU: \(process.formattedCPU)").font(.caption2).foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(memoryColor)
                ProgressView(value: min(Double(process.memoryUsage) / (4 * 1024 * 1024 * 1024), 1.0)).frame(width: 50).tint(memoryColor)
            }
            
            Button(action: onKill) {
                Image(systemName: "stop.circle.fill").font(.system(size: 18)).foregroundColor(.red.opacity(isHovering ? 1 : 0.6))
            }.buttonStyle(.borderless).help("终止进程")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { isHovering = $0 }
    }
    
    private var memoryColor: Color {
        let memoryGB = Double(process.memoryUsage) / (1024 * 1024 * 1024)
        if memoryGB > 2 { return .red } else if memoryGB > 1 { return .orange } else { return .primary }
    }
}

struct ProcessListView: View {
    @ObservedObject var viewModel: ProcessViewModel
    @State private var showingKillAlert = false
    @State private var processToKill: AppProcessInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索进程...", text: $viewModel.searchText).textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.borderless)
                }
            }
            .padding(8).background(Color(NSColor.textBackgroundColor)).cornerRadius(8).padding(.horizontal, 12).padding(.vertical, 8)
            
            Divider()
            
            if viewModel.isLoading && viewModel.processes.isEmpty {
                VStack { ProgressView().scaleEffect(0.8); Text("加载中...").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredProcesses.isEmpty {
                VStack(spacing: 8) { Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundColor(.secondary); Text("未找到进程").font(.subheadline).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredProcesses) { process in
                            ProcessRowView(process: process) { processToKill = process; showingKillAlert = true }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .alert("确认终止进程", isPresented: $showingKillAlert, presenting: processToKill) { process in
            Button("取消", role: .cancel) { }
            Button("终止", role: .destructive) { viewModel.terminateProcess(process, force: true) { _ in } }
        } message: { process in
            Text("确定要终止进程 \"\(process.name)\" (PID: \(process.pid)) 吗？\n\n⚠️ 未保存的数据可能会丢失。")
        }
    }
}

struct PortRowView: View {
    let portInfo: PortInfo
    let onRelease: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(portColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: "network").font(.system(size: 14)).foregroundColor(portColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(":\(portInfo.port)").font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text(portInfo.protocolType).font(.system(size: 9, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 2).background(portInfo.protocolType == "TCP" ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15)).foregroundColor(portInfo.protocolType == "TCP" ? .blue : .purple).cornerRadius(4)
                    Text(portInfo.state).font(.system(size: 9, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 2).background(stateColor.opacity(0.15)).foregroundColor(stateColor).cornerRadius(4)
                }
                HStack(spacing: 4) {
                    Text(portInfo.processName).font(.caption).foregroundColor(.secondary)
                    Text("(PID: \(portInfo.pid))").font(.caption2).foregroundColor(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: onRelease) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(.red.opacity(isHovering ? 1 : 0.6))
            }.buttonStyle(.borderless).help("释放端口")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { isHovering = $0 }
    }
    
    private var portColor: Color {
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

struct PortListView: View {
    @ObservedObject var viewModel: PortViewModel
    @State private var showingReleaseAlert = false
    @State private var portToRelease: PortInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索端口或进程...", text: $viewModel.searchText).textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.borderless)
                }
            }
            .padding(8).background(Color(NSColor.textBackgroundColor)).cornerRadius(8).padding(.horizontal, 12).padding(.vertical, 8)
            
            Divider()
            
            if viewModel.isLoading && viewModel.ports.isEmpty {
                VStack { ProgressView().scaleEffect(0.8); Text("加载中...").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredPorts.isEmpty {
                VStack(spacing: 8) { Image(systemName: "network.slash").font(.largeTitle).foregroundColor(.secondary); Text("未找到端口").font(.subheadline).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredPorts) { port in
                            PortRowView(portInfo: port) { portToRelease = port; showingReleaseAlert = true }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .alert("确认释放端口", isPresented: $showingReleaseAlert, presenting: portToRelease) { port in
            Button("取消", role: .cancel) { }
            Button("释放", role: .destructive) { viewModel.releasePort(port) { _ in } }
        } message: { port in
            Text("确定要释放端口 \(port.port) 吗？\n\n这将终止进程 \"\(port.processName)\" (PID: \(port.pid))。")
        }
    }
}

struct CacheRowView: View {
    let cache: CacheInfo
    let onClean: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: cache.icon)
                    .font(.system(size: 14))
                    .foregroundColor(categoryColor)
            }
            
            // 缓存信息
            VStack(alignment: .leading, spacing: 2) {
                Text(cache.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Text(cache.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(categoryColor.opacity(0.15))
                    .foregroundColor(categoryColor)
                    .cornerRadius(3)
            }
            
            Spacer()
            
            // 大小
            Text(cache.formattedSize)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(sizeColor)
            
            // 清理按钮
            Button(action: onClean) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange.opacity(isHovering ? 1 : 0.6))
            }
            .buttonStyle(.borderless)
            .help("清理缓存")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { isHovering = $0 }
    }
    
    private var categoryColor: Color {
        switch cache.category {
        case .browser: return .blue
        case .system: return .orange
        case .app: return .purple
        }
    }
    
    private var sizeColor: Color {
        let sizeGB = Double(cache.size) / (1024 * 1024 * 1024)
        if sizeGB > 1 { return .red }
        else if sizeGB > 0.5 { return .orange }
        else { return .primary }
    }
}

struct DiskInfoCard: View {
    let diskInfo: DiskInfo
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.blue)
                Text("磁盘空间")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(diskInfo.formattedUsed) / \(diskInfo.formattedTotal)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: diskInfo.usagePercentage)
                .tint(diskInfo.usagePercentage > 0.9 ? .red : diskInfo.usagePercentage > 0.7 ? .orange : .blue)
            HStack {
                Text("可用: \(diskInfo.formattedFree)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct CacheDetailView: View {
    let cache: CacheInfo?
    let files: [CacheFileInfo]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                if let cache = cache {
                    Image(systemName: cache.icon)
                        .foregroundColor(.blue)
                    Text(cache.name)
                        .font(.headline)
                } else {
                    Text("缓存详情")
                        .font(.headline)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding()
            
            Divider()
            
            // 路径信息
            if let cache = cache {
                HStack {
                    Text("路径:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(cache.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            Divider()
            
            // 文件列表
            if files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("没有文件")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(files) { file in
                            HStack(spacing: 10) {
                                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundColor(file.isDirectory ? .blue : .gray)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Text(file.formattedDate)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(file.formattedSize)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            
            // 底部统计
            if !files.isEmpty {
                Divider()
                HStack {
                    Text("共 \(files.count) 项")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(width: 400, height: 380)
    }
}

struct CacheListView: View {
    @ObservedObject var viewModel: CacheViewModel
    @State private var showingCleanAlert = false
    @State private var cacheToClean: CacheInfo?
    @State private var showingCleanAllAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 磁盘空间信息
            DiskInfoCard(diskInfo: viewModel.diskInfo)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            // 一键清理按钮
            Button(action: { showingCleanAllAlert = true }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("一键清理所有缓存")
                    Spacer()
                    Text(viewModel.formattedTotalSize)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(
                    LinearGradient(colors: [.orange.opacity(0.1), .red.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .disabled(viewModel.isClearing || viewModel.caches.isEmpty)
            
            Divider()
            
            if viewModel.isLoading && viewModel.caches.isEmpty {
                VStack {
                    ProgressView().scaleEffect(0.8)
                    Text("扫描中...").font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.caches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("太棒了，没有可清理的缓存！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.caches) { cache in
                            CacheRowView(cache: cache) {
                                cacheToClean = cache
                                showingCleanAlert = true
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.loadCacheDetails(cache)
                            }
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            
            if viewModel.isClearing {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("正在清理...").font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
        .sheet(isPresented: $viewModel.showCacheDetails) {
            CacheDetailView(cache: viewModel.selectedCache, files: viewModel.selectedCacheFiles)
        }
        .alert("确认清理", isPresented: $showingCleanAlert, presenting: cacheToClean) { cache in
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                viewModel.cleanCache(cache) { _, _ in }
            }
        } message: { cache in
            Text("确定要清理 \"\(cache.name)\" 吗？\n大小: \(cache.formattedSize)\n\n⚠️ 此操作不可恢复")
        }
        .alert("一键清理所有缓存", isPresented: $showingCleanAllAlert) {
            Button("取消", role: .cancel) { }
            Button("清理全部", role: .destructive) {
                viewModel.cleanAllCaches { _ in }
            }
        } message: {
            Text("确定要清理所有缓存吗？\n总大小: \(viewModel.formattedTotalSize)\n\n包括浏览器缓存、系统缓存和应用缓存。\n⚠️ 此操作不可恢复")
        }
        .alert("清理完成", isPresented: $viewModel.showCleanResult) {
            Button("好的") { }
        } message: {
            Text("已释放 \(viewModel.formattedCleanedSize) 空间！")
        }
    }
}

struct ContentView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var processViewModel: ProcessViewModel
    @ObservedObject var portViewModel: PortViewModel
    @ObservedObject var cacheViewModel: CacheViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "memorychip").font(.title2).foregroundColor(.blue)
                Text("Mac 性能监控").font(.headline).fontWeight(.semibold)
                Spacer()
                Button(action: { appViewModel.refresh(); processViewModel.refresh(); portViewModel.refresh(); cacheViewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14))
                }.buttonStyle(.borderless).help("刷新")
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle").font(.system(size: 14)).foregroundColor(.secondary)
                }.buttonStyle(.borderless).help("退出")
            }
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color(NSColor.controlBackgroundColor))
            
            // Tabs
            Picker("", selection: $selectedTab) {
                Text("📱 应用").tag(0)
                Text("💻 进程").tag(1)
                Text("🔌 端口").tag(2)
                Text("🧹 清理").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    AppListView(viewModel: appViewModel)
                case 1:
                    ProcessListView(viewModel: processViewModel)
                case 2:
                    PortListView(viewModel: portViewModel)
                case 3:
                    CacheListView(viewModel: cacheViewModel)
                default:
                    AppListView(viewModel: appViewModel)
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                if selectedTab == 0 {
                    Text("共 \(appViewModel.filteredApps.count) 个应用").font(.caption).foregroundColor(.secondary)
                    Spacer()
                } else if selectedTab == 1 {
                    HStack(spacing: 4) {
                        Circle().fill(memoryColor).frame(width: 8, height: 8)
                        Text("内存: \(processViewModel.formattedUsedMemory) / \(processViewModel.formattedTotalMemory)").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    ProgressView(value: processViewModel.memoryUsagePercentage).frame(width: 80).tint(memoryColor)
                } else if selectedTab == 2 {
                    Text("共 \(portViewModel.filteredPorts.count) 个端口").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Toggle("仅监听", isOn: $portViewModel.showListeningOnly).toggleStyle(.checkbox).font(.caption)
                } else {
                    Text("可清理: \(cacheViewModel.formattedTotalSize)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button(action: { cacheViewModel.refresh() }) {
                        Text("重新扫描").font(.caption)
                    }.buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8).background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var memoryColor: Color {
        let usage = processViewModel.memoryUsagePercentage
        if usage > 0.9 { return .red } else if usage > 0.7 { return .orange } else { return .green }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var appViewModel = AppViewModel()
    private var processViewModel = ProcessViewModel()
    private var portViewModel = PortViewModel()
    private var cacheViewModel = CacheViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "性能监控")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView(appViewModel: appViewModel, processViewModel: processViewModel, portViewModel: portViewModel, cacheViewModel: cacheViewModel))
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
