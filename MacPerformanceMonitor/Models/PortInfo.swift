import Foundation

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let pid: Int32
    let processName: String
    let protocolType: String  // TCP/UDP
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
