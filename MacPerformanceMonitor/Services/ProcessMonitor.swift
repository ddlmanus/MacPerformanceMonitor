import Foundation

class ProcessMonitor {
    
    static func getProcessList() -> [ProcessInfo] {
        // 使用 ps 命令获取进程信息，按内存使用量排序
        let command = "ps -axo pid,user,%cpu,rss,comm | tail -n +2 | sort -k4 -rn | head -100"
        let result = ShellExecutor.execute(command)
        
        guard result.exitCode == 0 else {
            print("Failed to get process list: \(result.error)")
            return []
        }
        
        return parseProcessOutput(result.output)
    }
    
    private static func parseProcessOutput(_ output: String) -> [ProcessInfo] {
        var processes: [ProcessInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // 解析每一行: PID USER %CPU RSS COMMAND
            let components = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard components.count >= 5 else { continue }
            
            guard let pid = Int32(components[0]),
                  let cpuUsage = Double(components[2]),
                  let rssKB = UInt64(components[3]) else { continue }
            
            let user = String(components[1])
            let name = String(components[4])
            
            // 提取应用名（去掉路径）
            let appName = (name as NSString).lastPathComponent
            
            // RSS 是以 KB 为单位，转换为 bytes
            let memoryBytes = rssKB * 1024
            
            // 过滤掉内存使用为 0 的进程
            guard memoryBytes > 0 else { continue }
            
            let process = ProcessInfo(
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
        // 获取总内存
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        
        // 使用 vm_stat 获取内存使用情况
        let result = ShellExecutor.execute("vm_stat")
        guard result.exitCode == 0 else {
            return (totalMemory, 0, totalMemory)
        }
        
        let pageSize: UInt64 = 4096
        var freePages: UInt64 = 0
        var activePages: UInt64 = 0
        var inactivePages: UInt64 = 0
        var wiredPages: UInt64 = 0
        var compressedPages: UInt64 = 0
        
        let lines = result.output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Pages free") {
                freePages = extractPageCount(from: line)
            } else if line.contains("Pages active") {
                activePages = extractPageCount(from: line)
            } else if line.contains("Pages inactive") {
                inactivePages = extractPageCount(from: line)
            } else if line.contains("Pages wired") {
                wiredPages = extractPageCount(from: line)
            } else if line.contains("Pages occupied by compressor") {
                compressedPages = extractPageCount(from: line)
            }
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
