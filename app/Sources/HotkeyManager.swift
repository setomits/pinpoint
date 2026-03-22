import AppKit
import ApplicationServices

class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    enum ModifierType: String {
        case control = "Control"
        case option = "Option"
        case command = "Command"
        case shift = "Shift"
        
        var modifierFlag: NSEvent.ModifierFlags {
            switch self {
            case .control: return .control
            case .option: return .option
            case .command: return .command
            case .shift: return .shift
            }
        }
    }
    
    private var targetTaps: Int {
        let taps = UserDefaults.standard.integer(forKey: "hotkeyTaps")
        return (3...5).contains(taps) ? taps : 3
    }
    
    private var timeWindow: TimeInterval {
        // 3 taps = 1.0s, 4 taps = 1.5s, 5 taps = 2.0s
        return TimeInterval(targetTaps - 1) * 0.5
    }
    
    private var targetModifier: ModifierType {
        if let str = UserDefaults.standard.string(forKey: "hotkeyModifier"), let mod = ModifierType(rawValue: str) {
            return mod
        }
        return .control
    }
    
    private var tapTimestamps: [Date] = []
    
    var onTrigger: (() -> Void)?
    
    init() {
        setupMonitor()
        checkAccessibility()
    }
    
    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            print("Accessibility access not granted. The app requires it to monitor the Control key.")
        }
    }
    
    private func setupMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        // Also listen locally just in case the app is miraculously key
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let target = targetModifier
        
        let isMatch: Bool
        switch target {
        case .control: isMatch = (event.keyCode == 59 || event.keyCode == 62)
        case .option: isMatch = (event.keyCode == 58 || event.keyCode == 61)
        case .command: isMatch = (event.keyCode == 55 || event.keyCode == 54)
        case .shift: isMatch = (event.keyCode == 56 || event.keyCode == 60)
        }
        
        if isMatch {
            if event.modifierFlags.contains(target.modifierFlag) {
                recordTap()
            }
        }
    }
    
    private func recordTap() {
        let now = Date()
        tapTimestamps.append(now)
        
        // Remove timestamps older than the dynamic time window
        let activeWindow = timeWindow
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) <= activeWindow }
        
        if tapTimestamps.count >= targetTaps {
            tapTimestamps.removeAll()
            onTrigger?()
        }
    }
    
    deinit {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
    }
}
