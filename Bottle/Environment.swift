import MetalKit
import simd

/// One world inside the bottle.
///
/// Every environment obeys the same rule: things are caught and kept. Stillness
/// adds another object and it stays; disturbance takes a share away. What that
/// looks like is entirely up to the world - lightning held in the air, ice
/// stacking up, elves arriving, a tree putting out branches.
@MainActor
protocol Environment: AnyObject {

    /// Shown briefly when swiped to, then it fades away.
    var title: String { get }

    var fragmentFunction: String { get }

    /// How many things a completely full bottle holds.
    var capacity: Int { get }

    /// `population` is how many objects the bottle has earned right now. The
    /// world's job is to converge on it, gradually, so filling is watchable.
    func update(delta: Double, population: Int, charge: Double, disturbance: Double)

    /// Called on the frame a disturbance begins, so the world can react in its
    /// own idiom rather than only shrinking in the background.
    func disturbed()

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double)
}
