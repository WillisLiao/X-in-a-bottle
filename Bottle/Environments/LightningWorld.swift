import MetalKit
import simd

/// Lightning in a Bottle. The free one.
///
/// Bolts are caught and kept. Each one that arrives stays in the bottle,
/// suspended and breathing, and the bottle visibly fills with them. A
/// disturbance shakes some of them loose.
final class LightningWorld: Environment {

    let title = "Lightning in a Bottle"
    let fragmentFunction = "lightning_fragment"
    let isPaid = false

    /// How long a caught bolt takes to fade in on arrival, and out when lost.
    private static let fadeSeconds: Double = 0.9

    /// Fraction shaken loose per disturbance. Not all of them: losing the lot
    /// would make a disturbance a reset rather than a cost.
    private static let lossFraction: Double = 0.30

    private struct Bolt {
        var points: [SIMD2<Double>]
        var alpha: Double
        var phase: Double
        var losing: Bool
    }

    private var bolts: [Bolt] = []
    private var time: Double = 0
    private var arrival: Double = 0
    private var sinceSpawn: Double = 0

    var onCatch: ((Double) -> Void)?

    let capacity = Int(kMaxBolts)

    func update(delta: Double, population: Int, charge: Double, disturbance: Double) {
        time += delta
        arrival = max(0, arrival - delta * 1.6)

        let wanted = min(population, capacity)
        let held = bolts.filter { !$0.losing }.count

        // Spaced out so the bottle fills visibly rather than all at once when
        // charge crosses a threshold.
        sinceSpawn += delta
        if held < wanted, sinceSpawn > 1.4, bolts.count < Int(kMaxBolts) {
            bolts.append(makeBolt())
            sinceSpawn = 0
            arrival = 1
            onCatch?(charge)
        }

        // If charge has fallen below what is held, the excess drifts away.
        if held > wanted, let index = bolts.firstIndex(where: { !$0.losing }) {
            bolts[index].losing = true
        }

        for i in bolts.indices {
            let target: Double = bolts[i].losing ? 0 : 1
            bolts[i].alpha += (target - bolts[i].alpha)
                * min(delta / Self.fadeSeconds, 1)
            bolts[i].phase += delta * (0.7 + 0.5 * Double(i % 5) * 0.3)
        }

        bolts.removeAll { $0.losing && $0.alpha < 0.02 }
    }

    func disturbed() {
        let held = bolts.filter { !$0.losing }
        let leaving = Int((Double(held.count) * Self.lossFraction).rounded(.up))
        guard leaving > 0 else { return }

        var lost = 0
        for i in bolts.indices.shuffled() where !bolts[i].losing {
            bolts[i].losing = true
            lost += 1
            if lost >= leaving { break }
        }
    }

    /// A bolt hanging in the bottle rather than falling through it: it starts
    /// and ends somewhere inside, and does not touch the edges.
    private func makeBolt() -> Bolt {
        let start = SIMD2(Double.random(in: 0.14...0.86), Double.random(in: 0.10...0.45))
        let angle = Double.random(in: 0..<(2 * .pi))
        let length = Double.random(in: 0.22...0.42)
        let end = simd_clamp(start + SIMD2(cos(angle), sin(angle)) * length,
                             SIMD2(0.08, 0.08), SIMD2(0.92, 0.92))

        return Bolt(points: Self.fork(from: start, to: end),
                    alpha: 0,
                    phase: Double.random(in: 0..<(2 * .pi)),
                    losing: false)
    }

    /// Midpoint displacement, three passes: 2 points become 3, 5, then 9. A
    /// larger initial offset and a slower decay than the textbook 0.5 keep
    /// high-frequency detail, without which it reads as a bent wire.
    private static func fork(from start: SIMD2<Double>,
                             to end: SIMD2<Double>) -> [SIMD2<Double>] {
        var pts = [start, end]
        var offset = 0.055

        for _ in 0..<3 {
            var next: [SIMD2<Double>] = [pts[0]]
            for i in 0..<(pts.count - 1) {
                let a = pts[i]
                let b = pts[i + 1]
                let along = b - a
                let normal = simd_normalize(SIMD2(-along.y, along.x))
                next.append((a + b) * 0.5 + normal * Double.random(in: -offset...offset))
                next.append(b)
            }
            pts = next
            offset *= 0.62
        }
        return pts
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double) {
        var u = LightningUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.time = Float(time)
        u.charge = Float(charge)
        u.disturbance = Float(disturbance)
        u.arrival = Float(arrival)
        u.ditherAmount = 1.0 / 1023.0

        let visible = Array(bolts.prefix(Int(kMaxBolts)))
        u.count = Int32(visible.count)

        let stride = Int(kBoltPoints)
        withUnsafeMutableBytes(of: &u.points) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (bi, bolt) in visible.enumerated() {
                for pi in 0..<stride {
                    let p = bolt.points[min(pi, bolt.points.count - 1)]
                    b[bi * stride + pi] = SIMD2(Float(p.x), Float(p.y))
                }
            }
        }

        // Bounds are stored in the same aspect-corrected space the shader
        // measures distance in. Storing them in raw UV and padding equally on
        // both axes is wrong by a factor of the aspect ratio, and clips every
        // halo into a visible rectangle down the sides.
        let aspect = Float(size.width / max(size.height, 1))

        // Far enough out that the halo has fallen to nothing.
        let pad: Float = 0.15

        withUnsafeMutableBytes(of: &u.boundsMin) { rawMin in
            withUnsafeMutableBytes(of: &u.boundsMax) { rawMax in
                let lo = rawMin.bindMemory(to: SIMD2<Float>.self)
                let hi = rawMax.bindMemory(to: SIMD2<Float>.self)
                for (bi, bolt) in visible.enumerated() {
                    var mn = SIMD2<Float>(.greatestFiniteMagnitude,
                                          .greatestFiniteMagnitude)
                    var mx = SIMD2<Float>(-.greatestFiniteMagnitude,
                                          -.greatestFiniteMagnitude)
                    for p in bolt.points {
                        let f = SIMD2(Float(p.x) * aspect, Float(p.y))
                        mn = simd_min(mn, f)
                        mx = simd_max(mx, f)
                    }
                    lo[bi] = mn - SIMD2(pad, pad)
                    hi[bi] = mx + SIMD2(pad, pad)
                }
            }
        }

        withUnsafeMutableBytes(of: &u.alphas) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, bolt) in visible.enumerated() { b[i] = Float(bolt.alpha) }
        }
        withUnsafeMutableBytes(of: &u.phases) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, bolt) in visible.enumerated() { b[i] = Float(bolt.phase) }
        }

        encoder.setFragmentBytes(&u, length: MemoryLayout<LightningUniforms>.stride, index: 0)
    }
}
