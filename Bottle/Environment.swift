import MetalKit
import simd

/// One world inside the bottle.
///
/// Every environment shares the same contract: stillness fills it, disturbance
/// empties it faster. What that looks like is entirely up to the world. Charge
/// is a storm gathering, or ice spreading, or genies arriving, and disturbance
/// is a blowout, a thaw, or an earthquake.
@MainActor
protocol Environment: AnyObject {

    /// Shown once when the environment is swiped to, then never again.
    var title: String { get }

    var fragmentFunction: String { get }

    /// True for everything except the default, which ships free.
    var isPaid: Bool { get }

    func update(delta: Double, charge: Double, disturbance: Double)

    /// Called on the frame a disturbance begins, so the world can react in its
    /// own idiom rather than only shrinking in the background.
    func disturbed()

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double)
}
