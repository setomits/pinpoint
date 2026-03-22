import AppKit
import ServiceManagement
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotkeyManager: HotkeyManager?
    var pinpointManager: PinpointManager?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        
        pinpointManager = PinpointManager()
        hotkeyManager = HotkeyManager()
        
        hotkeyManager?.onTrigger = { [weak self] in
            DispatchQueue.main.async {
                self?.pinpointManager?.showPinpoint()
            }
        }
        
        // Ensure accessibility permission (prompts only if not yet granted)
        ensureAccessibilityPermission()
    }
    
    private func setupMenuBar() {
        let currentAnim = UserDefaults.standard.string(forKey: "animationStyle") ?? "searchlight"
        let animName = (currentAnim == "searchlight") ?
            NSLocalizedString("AnimSearchlight", comment: "") :
            NSLocalizedString("AnimStagelight", comment: "")
        
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                // Load StatusBarIcon.png from the bundle (@2x/@3x selected automatically)
                if let icon = NSImage(named: "StatusBarIcon") {
                    icon.isTemplate = true // Apply tint automatically for Dark/Light modes
                    button.image = icon
                }
            }
        }
        
        let menu = NSMenu()
        
        // Settings Submenu
        let settingsMenu = NSMenuItem(title: NSLocalizedString("Settings", comment: ""), action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        
        // Target Modifier
        let modMenu = NSMenuItem(title: NSLocalizedString("ModifierKey", comment: ""), action: nil, keyEquivalent: "")
        let modSub = NSMenu()
        let currentMod = UserDefaults.standard.string(forKey: "hotkeyModifier") ?? "Control"
        for mod in ["Control", "Option", "Command", "Shift"] {
            let item = NSMenuItem(title: mod, action: #selector(changeModifier(_:)), keyEquivalent: "")
            item.target = self
            item.state = (currentMod == mod) ? .on : .off
            modSub.addItem(item)
        }
        modMenu.submenu = modSub
        subMenu.addItem(modMenu)
        
        // Target Tap Count
        let tapMenu = NSMenuItem(title: NSLocalizedString("TapCount", comment: ""), action: nil, keyEquivalent: "")
        let tapSub = NSMenu()
        let currentTaps = UserDefaults.standard.integer(forKey: "hotkeyTaps")
        let actualTaps = (currentTaps >= 3 && currentTaps <= 5) ? currentTaps : 3
        for tap in 3...5 {
            let format = NSLocalizedString("TapFormat", comment: "")
            let title = String(format: format, tap)
            let item = NSMenuItem(title: title, action: #selector(changeTaps(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tap
            item.state = (actualTaps == tap) ? .on : .off
            tapSub.addItem(item)
        }
        tapMenu.submenu = tapSub
        subMenu.addItem(tapMenu)
        
        // Target Radius Size
        let sizeFormat = NSLocalizedString("PinpointSize", comment: "")
        let radiusMenu = NSMenuItem(title: String(format: sizeFormat, animName), action: nil, keyEquivalent: "")
        let radiusSub = NSMenu()
        let currentRadius = UserDefaults.standard.integer(forKey: "pinpointRadius")
        let actualRadius = (currentRadius > 0) ? currentRadius : 100
        
        let labelSmall = NSLocalizedString("SizeSmall", comment: "")
        let labelLarge = NSLocalizedString("SizeLarge", comment: "")
        
        for (label, rad) in [(labelSmall, 100), (labelLarge, 173)] {
            let item = NSMenuItem(title: label, action: #selector(changeRadius(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = rad
            item.state = (actualRadius == rad) ? .on : .off
            radiusSub.addItem(item)
        }
        radiusMenu.submenu = radiusSub
        subMenu.addItem(radiusMenu)
        
        // Animation Style
        let animMenuTitle = NSLocalizedString("AnimationStyle", comment: "")
        let animMenu = NSMenuItem(title: animMenuTitle, action: nil, keyEquivalent: "")
        let animSub = NSMenu()
        
        let optSearch = NSLocalizedString("AnimSearchlight", comment: "")
        let optStage = NSLocalizedString("AnimStagelight", comment: "")
        
        for options in [(optSearch, "searchlight"), (optStage, "stagelight")] {
            let item = NSMenuItem(title: options.0, action: #selector(changeAnimation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = options.1
            item.state = (currentAnim == options.1) ? .on : .off
            animSub.addItem(item)
        }
        animMenu.submenu = animSub
        subMenu.addItem(animMenu)
        
        subMenu.addItem(NSMenuItem.separator())
        
        // Start at Login
        let launchMenu = NSMenuItem(title: NSLocalizedString("StartAtLogin", comment: ""), action: #selector(toggleAutoStart(_:)), keyEquivalent: "")
        launchMenu.target = self
        if #available(macOS 13.0, *) {
            launchMenu.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchMenu.state = UserDefaults.standard.bool(forKey: "autoStartFallback") ? .on : .off
        }
        subMenu.addItem(launchMenu)
        
        settingsMenu.submenu = subMenu
        menu.addItem(settingsMenu)
        
        menu.addItem(NSMenuItem.separator())
        
        let testFormat = NSLocalizedString("TestPinpoint", comment: "")
        let testTitle = String(format: testFormat, animName)
        menu.addItem(NSMenuItem(title: testTitle, action: #selector(testPinpoint), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: NSLocalizedString("QuitApp", comment: ""), action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleAutoStart(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                print("Failed to toggle auto start: \(error)")
            }
        } else {
            let current = UserDefaults.standard.bool(forKey: "autoStartFallback")
            UserDefaults.standard.set(!current, forKey: "autoStartFallback")
        }
        setupMenuBar()
    }
    
    @objc private func changeAnimation(_ sender: NSMenuItem) {
        if let anim = sender.representedObject as? String {
            UserDefaults.standard.set(anim, forKey: "animationStyle")
            setupMenuBar()
        }
    }
    
    @objc private func changeRadius(_ sender: NSMenuItem) {
        if let rad = sender.representedObject as? Int {
            UserDefaults.standard.set(rad, forKey: "pinpointRadius")
            setupMenuBar()
        }
    }
    
    @objc private func changeModifier(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.title, forKey: "hotkeyModifier")
        setupMenuBar() // Rebuild menu to update checkmarks
    }
    
    @objc private func changeTaps(_ sender: NSMenuItem) {
        if let taps = sender.representedObject as? Int {
            UserDefaults.standard.set(taps, forKey: "hotkeyTaps")
            setupMenuBar() // Rebuild menu to update checkmarks
        }
    }
    
    @objc private func testPinpoint() {
        pinpointManager?.showPinpoint()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func ensureAccessibilityPermission() {
        // Prompt the system to show Accessibility permission dialog if not trusted yet.
        // This only shows once until the user grants permission in System Settings.
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

