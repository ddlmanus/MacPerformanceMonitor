import Foundation

struct ProcessInfo: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let memoryUsage: UInt64  // bytes
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
    
    static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}
