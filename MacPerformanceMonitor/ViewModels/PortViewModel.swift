import Foundation
import SwiftUI

class PortViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var showListeningOnly = true
    
    private var timer: Timer?
    
    var filteredPorts: [PortInfo] {
        var result = ports
        
        if showListeningOnly {
            result = result.filter { $0.state.uppercased() == "LISTEN" }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.processName.localizedCaseInsensitiveContains(searchText) ||
                String($0.port).contains(searchText)
            }
        }
        
        return result
    }
    
    init() {
        refresh()
        startAutoRefresh()
    }
    
    func refresh() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let portList = PortMonitor.getPortList()
            
            DispatchQueue.main.async {
                self?.ports = portList
                self?.isLoading = false
            }
        }
    }
    
    func startAutoRefresh(interval: TimeInterval = 10.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func releasePort(_ portInfo: PortInfo, force: Bool = true, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = PortMonitor.releasePort(pid: portInfo.pid, force: force)
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
