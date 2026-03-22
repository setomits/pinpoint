import AppKit
import SwiftUI

class PinpointManager {
    private var windows: [NSWindow] = []
    private var hideTimer: Timer?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    fileprivate var showTimestamp: Date = Date()
    
    private var mouseLocationTracker = MouseLocationTracker()

    func showPinpoint() {
        // Reset hide timer
        hideTimer?.invalidate()
        showTimestamp = Date()
        
        // Remove existing windows
        closeAllWindows()
        
        mouseLocationTracker.start()
        
        // Create a window for each screen
        for screen in NSScreen.screens {
            let window = PinpointWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: nil // Use nil to treat contentRect as absolute global space
            )
            
            // Set up transparent overlay properties
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            // Support spanning multiple spaces perfectly
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            
            // Explicitly force the frame after creation to guarantee no shifts
            window.setFrame(screen.frame, display: true)
            
            let view = PinpointView(tracker: mouseLocationTracker, screenFrame: screen.frame)
            window.contentView = NSHostingView(rootView: view)
            
            window.makeKeyAndOrderFront(nil)
            
            // Animate alpha
            window.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 1.0
            }
            
            windows.append(window)
        }
        
        // Start hide timer
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hidePinpoint(fast: false)
        }
        
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            if Date().timeIntervalSince(self.showTimestamp) < 0.2 { return }
            
            // Ignore normal mouse motion so it tracks the cursor properly
            let ignored: [NSEvent.EventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
            if ignored.contains(event.type) { return }
            
            DispatchQueue.main.async {
                self.hidePinpoint(fast: true)
            }
        }
        
        // Use .any to broadly catch EVERYTHING system-wide, securely.
        let mask = NSEvent.EventTypeMask.any
        
        if globalEventMonitor == nil {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        }
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
                handler(event)
                return event
            }
        }
    }
    
    @objc func hidePinpoint(fast: Bool = false) {
        hideTimer?.invalidate()
        mouseLocationTracker.stop()
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        let targetWindows = windows
        windows.removeAll()
        
        for window in targetWindows {
            if fast {
                window.close()
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0.0
                }, completionHandler: {
                    window.close()
                })
            }
        }
    }
    
    private func closeAllWindows() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }
}

class PinpointWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class MouseLocationTracker: ObservableObject {
    @Published var location: NSPoint = NSEvent.mouseLocation
    private var timer: Timer?
    
    func start() {
        location = NSEvent.mouseLocation
        timer?.invalidate()
        // Poll for smooth movement (60fps is 0.016s)
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            let newLocation = NSEvent.mouseLocation
            if self?.location != newLocation {
                self?.location = newLocation
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
