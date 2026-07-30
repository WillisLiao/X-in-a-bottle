import MetalKit
import UIKit
import simd

/// The bottle.
///
/// Owns the charge, the motion sensing and the set of environments, and hands
/// the active one whatever it needs. The phone is the vessel, so nothing here
/// draws one.
final class BottleRenderer: NSObject, CanvasRenderer {

    private(set) var environments: [any Environment] = [
        LightningWorld(),
        IceWorld(),
        GenieWorld(),
    ]

    private(set) var index = 0

    var active: any Environment { environments[index] }

    var fragmentFunction: String { active.fragmentFunction }

    let charge = Charge()

    private let motion = MotionMonitor()
    private let arrivalFeedback = UIImpactFeedbackGenerator(style: .rigid)

    private var size = CGSize(width: 1, height: 1)
    private var touchedThisFrame = false
    private var disturbance: Double = 0
    private var wasDisturbed = false

    override init() {
        super.init()
        motion.start()

        // Every environment marks an arrival the same way, because catching
        // something is the same event whatever it is.
        for env in environments {
            switch env {
            case let world as LightningWorld:
                world.onCatch = { [weak self] charge in
                    self?.caught(intensity: 0.30 + 0.5 * charge)
                }
            case let world as IceWorld:
                world.onForm = { [weak self] in self?.caught(intensity: 0.35) }
            case let world as GenieWorld:
                world.onArrive = { [weak self] in self?.caught(intensity: 0.30) }
            default:
                break
            }
        }
    }

    /// Nothing here is a brief event any more: everything caught stays caught,
    /// so there is no fast moment to miss. 30 is plenty and halves the cost of
    /// shaders that loop over every object for every pixel.
    var preferredFPS: Int { 30 }

    private func caught(intensity: Double) {
        arrivalFeedback.impactOccurred(intensity: intensity)
    }

    /// A bottle is never finished. It is left, not completed.
    var isFinished: Bool { false }

    /// Swiping is how you change environment. It still costs, because it is
    /// still touching the phone, but far less than fiddling.
    func swipe(forward: Bool) {
        let next = index + (forward ? 1 : -1)
        guard environments.indices.contains(next) else { return }
        index = next
    }

    func touched(at point: SIMD2<Double>) {
        // Never an interaction. There is nothing to do here, and the nothing is
        // the product.
        touchedThisFrame = true
        charge.disturb()
    }

    func advance(by delta: Double, drawableSize: CGSize) {
        size = drawableSize

        charge.update(delta: delta,
                      agitation: motion.agitation,
                      touched: touchedThisFrame)
        touchedThisFrame = false

        // Eased so the recoil reads as the world flinching rather than as a
        // value snapping between two states.
        let target: Double = charge.isDisturbed ? 1 : 0
        disturbance += (target - disturbance) * min(delta * 6, 1)

        if charge.isDisturbed && !wasDisturbed {
            active.disturbed()
        }
        wasDisturbed = charge.isDisturbed

        active.update(delta: delta, charge: charge.level, disturbance: disturbance)
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder) {
        active.encodeUniforms(into: encoder,
                              size: size,
                              charge: charge.level,
                              disturbance: disturbance)
    }
}
