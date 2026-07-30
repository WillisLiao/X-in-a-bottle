import Foundation

/// How much storm there is.
///
/// Stillness fills the bottle. Touching the screen or moving the phone drains
/// it, and drains it much faster than stillness fills it. That asymmetry is the
/// entire mechanism: a ten second glance at a notification has to cost real
/// progress, or there is no reason to leave the phone alone.
final class Charge {

    /// Perfect stillness needed to fill the bottle from empty.
    static let fillSeconds: Double = 25 * 60

    /// Disturbance drains this many times faster than stillness fills. At 12x,
    /// a ten second pick-up costs two minutes of focus.
    static let drainMultiplier: Double = 12

    /// Movement below this is a desk, a passing lorry, someone walking past.
    /// Above it is a hand.
    static let agitationThreshold: Double = 0.035

    /// After a disturbance ends, the storm waits before rebuilding. Without
    /// this the bottle starts refilling the instant the phone lands, which
    /// makes putting it down feel like it undoes picking it up.
    static let settleSeconds: Double = 2.5

    private(set) var level: Double = 0
    private(set) var isDisturbed = false

    private var settling: Double = 0

    func update(delta: Double, agitation: Double, touched: Bool) {
        let disturbed = touched || agitation > Self.agitationThreshold
        isDisturbed = disturbed

        if disturbed {
            settling = Self.settleSeconds
            level = max(0, level - delta * Self.drainMultiplier / Self.fillSeconds)
            return
        }

        if settling > 0 {
            settling = max(0, settling - delta)
            return
        }

        level = min(1, level + delta / Self.fillSeconds)
    }

    /// A touch is always a disturbance, never an interaction. There is nothing
    /// to do in this app, and that is the point.
    func disturb() {
        settling = Self.settleSeconds
        level = max(0, level - 0.004)
    }
}
