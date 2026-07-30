import MetalKit
import UIKit
import simd

/// Drives Lull's world from the decay curve.
final class LullRenderer: NSObject, CanvasRenderer {

    /// How quickly the ember chases the touch point. Low on purpose: the lag is
    /// what makes steering feel unhurried rather than twitchy.
    private static let followSpeed: Double = 0.6

    /// How far the ember keeps drifting on its own, per second in UV space,
    /// once nobody is steering.
    private static let idleDrift: Double = 0.012

    let fragmentFunction = "drift_fragment"

    let decay = Decay()
    let presences = PresenceField()

    private let foundFeedback = UIImpactFeedbackGenerator(style: .soft)

    private var drift: Double = 0
    private var light = SIMD2<Double>(0.5, 0.5)
    private var target = SIMD2<Double>(0.5, 0.5)
    private var idleHeading = SIMD2<Double>(0, 0)
    private var size = CGSize(width: 1, height: 1)

    override init() {
        super.init()

        idleHeading = Self.randomHeading()

        presences.onFound = { [weak self] in
            // The only feedback a found thing gets. No sound yet, no counter,
            // and there will never be a counter.
            self?.foundFeedback.impactOccurred(intensity: 0.4)
        }

        decay.onLetGo = { [weak self] in
            // Deliberately silent. No dialog, no "are you still there", no
            // dimming warning that wants a tap. The world simply carries on.
            self?.idleHeading = Self.randomHeading()
        }
    }

    var preferredFPS: Int { decay.targetFPS }

    var isFinished: Bool { decay.fade >= 1 }

    func touched(at point: SIMD2<Double>) {
        target = simd_clamp(point, SIMD2(0, 0), SIMD2(1, 1))
        decay.touched()
    }

    func advance(by delta: Double, drawableSize: CGSize) {
        size = drawableSize

        decay.advance(by: delta)
        drift += delta * decay.timeScale

        if decay.isLettingGo {
            // Nobody is steering. The ember keeps its own course rather than
            // stopping, because stopping reads as a crash.
            target += idleHeading * Self.idleDrift * delta
            if target.x <= 0.15 || target.x >= 0.85 { idleHeading.x *= -1 }
            if target.y <= 0.15 || target.y >= 0.85 { idleHeading.y *= -1 }
            target = simd_clamp(target, SIMD2(0.15, 0.15), SIMD2(0.85, 0.85))
        }

        light += (target - light) * min(Self.followSpeed * delta, 1)

        presences.update(delta: delta, light: light, progress: decay.progress)
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder) {
        var u = LullUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.lightPos = SIMD2(Float(light.x), Float(light.y))
        u.drift = Float(drift)
        u.luminance = Float(decay.luminance)
        u.saturation = Float(decay.saturation)

        // Tuned by eye on device in a dark room. The simulator cannot show what
        // an OLED does at low brightness, so these came from the phone.
        u.lightRadius = 0.12
        u.lightIntensity = 0.10

        u.presencePos = SIMD2(Float(presences.position.x), Float(presences.position.y))
        u.presenceResolve = Float(presences.resolve)

        // Faint enough at range to be noticed rather than read, stronger as the
        // ember closes in so approaching feels like confirmation.
        u.presenceHint = presences.isPresent
            ? Float(0.012 + 0.033 * presences.proximity(to: light))
            : 0

        u.ditherAmount = 1.0 / 1023.0

        // Reduce Motion scales the drifting field down instead of freezing it,
        // so the world stays alive for people who cannot tolerate the movement.
        u.motionScale = UIAccessibility.isReduceMotionEnabled ? 0.25 : 1.0

        encoder.setFragmentBytes(&u, length: MemoryLayout<LullUniforms>.stride, index: 0)
    }

    private static func randomHeading() -> SIMD2<Double> {
        let angle = Double.random(in: 0..<(2 * .pi))
        return SIMD2(cos(angle), sin(angle))
    }
}
