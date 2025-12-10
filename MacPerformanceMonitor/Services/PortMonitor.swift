import Foundation

class PortMonitor {
    
    static func getPortList() -> [PortInfo] {
        // 使用 lsof 获取监听端口
        let command = "lsof -i -P -n 2>/dev/null | grep -E '(LISTEN|ESTABLISHED)' | head -200"
        let result = ShellExecutor.execute(command)
        
        guard result.exitCode == 0 || !result.output.isEmpty else {
            print("Failed to get port list: \(result.error)")
            return []
        }
        
        return parsePortOutput(result.output)
    }
    
    private static func parsePortOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        var seenPorts: Set<String> = []
        
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // lsof 输出格式: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }
            
            let processName = String(components[0])
            guard let pid = Int32(components[1]) else { continue }
            
            // 解析 NAME 字段 (最后一个字段包含地址和状态)
            let nameIndex = components.count - 1
            let stateIndex = components.count - 1
            
            var nameStr = String(components[nameIndex])
            var state = ""
            
            // 检查是否包含状态信息
            if nameStr.contains("(") {
                if let stateMatch = nameStr.components(separatedBy: "(").last {
                    state = stateMatch.replacingOccurrences(of: ")", with: "")
                }
                nameStr = nameStr.components(separatedBy: "(").first ?? nameStr
            }
            
            // 解析端口号
            var port = 0
            var localAddress = nameStr
            
            if nameStr.contains(":") {
                let addressParts = nameStr.components(separatedBy: ":")
                if let portStr = addressParts.last, let portNum = Int(portStr) {
                    port = portNum
                    localAddress = nameStr
                }
            }
            
            // 确定协议类型
            let protocolType = line.contains("TCP") ? "TCP" : (line.contains("UDP") ? "UDP" : "TCP")
            
            // 跳过无效端口或重复项
            guard port > 0 else { continue }
            
            let uniqueKey = "\(port)-\(pid)"
            guard !seenPorts.contains(uniqueKey) else { continue }
            seenPorts.insert(uniqueKey)
            
            let portInfo = PortInfo(
                port: port,
                pid: pid,
                processName: processName,
                protocolType: protocolType,
                state: state,
                localAddress: localAddress
            )
            ports.append(portInfo)
        }
        
        // 按端口号排序
        return ports.sorted { $0.port < $1.port }
    }
    
    static func releasePort(pid: Int32, force: Bool = false) -> Bool {
        return ShellExecutor.killProcess(pid: pid, force: force)
    }
}
