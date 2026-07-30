import MetalKit
import simd

/// Ice in a Bottle. Paid.
///
/// Crystals nucleate and spread while the phone is still. Moving it thaws them,
/// and the ones nearest the edges go first.
final class IceWorld: Environment {

    let title = "Ice in a Bottle"
    let fragmentFunction = "ice_fragment"
    let isPaid = true

    /// How fast a crystal creeps outward once it has nucleated.
    private static let growthPerSecond: Double = 0.0075

    /// Thaw takes back this much radius per second while disturbed. Far faster
    /// than growth, which is the same asymmetry the whole app runs on.
    private static let thawPerSecond: Double = 0.075

    private static let maxRadius: Double = 0.30

    private var seeds: [SIMD2<Double>] = []
    private var radii: [Double] = []
    private var time: Double = 0
    private var melt: Double = 0

    init() {
        // Fixed for a session rather than random per frame, so ice always
        // regrows in the same places it was lost from. Losing your ice and
        // getting back a different pattern would feel like a reset.
        for _ in 0..<Int(kMaxCrystals) {
            seeds.append(SIMD2(Double.random(in: -0.05...1.05),
                               Double.random(in: -0.05...1.05)))
            radii.append(0)
        }
    }

    func update(delta: Double, charge: Double, disturbance: Double) {
        time += delta
        melt = max(0, melt - delta * 1.6)

        // How many crystals this much charge is entitled to. The rest stay
        // dormant, so a nearly empty bottle is a few specks and not a thin
        // haze over the whole screen.
        let entitled = Int((Double(kMaxCrystals) * charge).rounded(.up))
        let ceiling = Self.maxRadius * (0.35 + 0.65 * charge)

        for i in radii.indices {
            if disturbance > 0.5 {
                radii[i] = max(0, radii[i] - delta * Self.thawPerSecond)
            } else if i < entitled {
                radii[i] = min(ceiling, radii[i] + delta * Self.growthPerSecond)
            } else {
                radii[i] = max(0, radii[i] - delta * Self.growthPerSecond)
            }
        }
    }

    func disturbed() {
        melt = 1
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double) {
        var u = IceUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.time = Float(time)
        u.charge = Float(charge)
        u.disturbance = Float(disturbance)
        u.melt = Float(melt)
        u.ditherAmount = 1.0 / 1023.0
        u.count = Int32(kMaxCrystals)

        withUnsafeMutableBytes(of: &u.seeds) { raw in
            let buffer = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, s) in seeds.enumerated() { buffer[i] = SIMD2(Float(s.x), Float(s.y)) }
        }
        withUnsafeMutableBytes(of: &u.radii) { raw in
            let buffer = raw.bindMemory(to: Float.self)
            for (i, r) in radii.enumerated() { buffer[i] = Float(r) }
        }

        encoder.setFragmentBytes(&u, length: MemoryLayout<IceUniforms>.stride, index: 0)
    }
}
