import Foundation

class ShellExecutor {
    
    static func execute(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.environment = ProcessInfo.processInfo.environment
        
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
    
    static func executeAsync(_ command: String, completion: @escaping (String, String, Int32) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = execute(command)
            DispatchQueue.main.async {
                completion(result.output, result.error, result.exitCode)
            }
        }
    }
    
    static func killProcess(pid: Int32, force: Bool = false) -> Bool {
        let signal = force ? "-9" : "-15"
        let result = execute("kill \(signal) \(pid)")
        return result.exitCode == 0
    }
}
