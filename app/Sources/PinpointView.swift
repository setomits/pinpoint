import SwiftUI

struct PinpointView: View {
    @ObservedObject var tracker: MouseLocationTracker
    let screenFrame: NSRect
    
    @State private var pinpointRadius: CGFloat
    @State private var pinpointOffset: CGSize
    private let targetRadius: CGFloat
    private let animStyle: String
    
    init(tracker: MouseLocationTracker, screenFrame: NSRect) {
        self.tracker = tracker
        self.screenFrame = screenFrame
        
        let storedRadius = UserDefaults.standard.integer(forKey: "pinpointRadius")
        let tRad = storedRadius > 0 ? CGFloat(storedRadius) : 100
        self.targetRadius = tRad
        
        self.animStyle = UserDefaults.standard.string(forKey: "animationStyle") ?? "searchlight"
        
        if self.animStyle == "searchlight" {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance: Double = max(screenFrame.width, screenFrame.height) * 1.5 // Start way off-screen
            _pinpointOffset = State(initialValue: CGSize(width: cos(angle) * distance, height: sin(angle) * distance))
            _pinpointRadius = State(initialValue: tRad * 3.0) // Start as a wide beam
        } else {
            _pinpointOffset = State(initialValue: .zero)
            _pinpointRadius = State(initialValue: 3000)
        }
    }
    
    var body: some View {
        let mousePos = globalToLocal(mouseLocation: tracker.location, screenFrame: screenFrame)
        
        Color.black.opacity(0.85)
            .mask(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black.opacity(0.0), location: 0.0),
                        .init(color: .black.opacity(0.0), location: 0.1),
                        .init(color: .black.opacity(0.5), location: 0.6),
                        .init(color: .black.opacity(1.0), location: 1.0)
                    ]),
                    center: UnitPoint(
                        x: (mousePos.x + pinpointOffset.width) / screenFrame.width,
                        y: (mousePos.y + pinpointOffset.height) / screenFrame.height
                    ),
                    startRadius: 0,
                    endRadius: pinpointRadius
                )
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                if animStyle == "searchlight" {
                    // Dramatic sweeping searchlight with a slight elastic overshoot
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.55, blendDuration: 0)) {
                        pinpointOffset = .zero
                        pinpointRadius = targetRadius
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.35)) {
                        pinpointRadius = targetRadius
                    }
                }
            }
    }
    
    func globalToLocal(mouseLocation: NSPoint, screenFrame: NSRect) -> CGPoint {
        // AppKit coordinates origin is bottom-left of primary screen.
        // screenFrame defines this screen's rect in that global space.
        
        // View x coordinate
        let x = mouseLocation.x - screenFrame.minX
        
        // Invert y coordinate because SwiftUI view origin is top-left
        let fromBottom = mouseLocation.y - screenFrame.minY
        let y = screenFrame.height - fromBottom
        
        return CGPoint(x: x, y: y)
    }
}
