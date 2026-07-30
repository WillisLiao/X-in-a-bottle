import MetalKit
import simd

/// Lightning in a Bottle. The free one.
///
/// Bolts fall from the top of the screen. A weak bottle throws short flickers
/// near the top; a full one reaches all the way down.
final class LightningWorld: Environment {

    let title = "Lightning in a Bottle"
    let fragmentFunction = "lightning_fragment"
    let isPaid = false

    /// Gap between strikes at an empty bottle and at a full one. Waiting is
    /// most of what watching a storm is, so even a full bottle breathes.
    private static let quietWhenEmpty: ClosedRange<Double> = 9.0...22.0
    private static let quietWhenFull: ClosedRange<Double> = 1.1...3.4

    /// The first attempt at 0.16 was physically defensible and meant the bolt
    /// was never actually seen: at 60fps it occupied a handful of frames and
    /// every glance caught only the afterglow.
    private static let boltSeconds: Double = 0.30
    private static let flashSeconds: Double = 0.85

    private static let origin = SIMD2<Double>(0.5, -0.02)

    private var points: [SIMD2<Double>] = []
    private var flash: Double = 0
    private var boltAlpha: Double = 0
    private var untilNext: Double = 1.2
    private var boltAge: Double = .greatestFiniteMagnitude
    private var flashAge: Double = .greatestFiniteMagnitude
    private var time: Double = 0

    var onStrike: ((Double) -> Void)?

    func update(delta: Double, charge: Double, disturbance: Double) {
        time += delta
        boltAge += delta
        flashAge += delta

        // Real lightning restrikes down the same channel several times in quick
        // succession, which is why it flickers rather than simply switching off.
        let envelope = max(0, 1 - boltAge / Self.boltSeconds)
        boltAlpha = envelope * (0.55 + 0.45 * cos(boltAge * 62))

        // Squared so the afterglow falls the way light does: fast, then lingering.
        let f = max(0, 1 - flashAge / Self.flashSeconds)
        flash = f * f

        untilNext -= delta
        if untilNext <= 0 { strike(charge: charge) }
    }

    /// A blowout. The storm is knocked back rather than merely reduced.
    func disturbed() {
        untilNext = max(untilNext, 2.0)
    }

    private func strike(charge: Double) {
        // A weak bottle only sparks near the top. Pulling the endpoint back
        // toward the origin makes charge legible as reach, not just brightness.
        let extent = 0.20 + 0.80 * charge
        let free = SIMD2(Double.random(in: 0.12...0.88), Double.random(in: 0.30...1.02))
        let end = Self.origin + (free - Self.origin) * extent

        points = Self.fork(from: Self.origin, to: end, scale: extent)
        boltAge = 0
        flashAge = 0

        let lo = Self.quietWhenEmpty.lowerBound
            + (Self.quietWhenFull.lowerBound - Self.quietWhenEmpty.lowerBound) * charge
        let hi = Self.quietWhenEmpty.upperBound
            + (Self.quietWhenFull.upperBound - Self.quietWhenEmpty.upperBound) * charge
        untilNext = Double.random(in: lo...hi)

        onStrike?(charge)
    }

    /// Midpoint displacement. A larger initial offset and a slower decay than
    /// the textbook 0.5 keep high-frequency detail in the later passes; at the
    /// textbook values the result read as a crack rather than as lightning.
    private static func fork(from start: SIMD2<Double>,
                             to end: SIMD2<Double>,
                             scale: Double) -> [SIMD2<Double>] {
        var pts = [start, end]
        var offset = 0.085 * scale

        for _ in 0..<4 {
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

        return Array(pts.prefix(Int(kMaxBoltPoints)))
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double) {
        var u = LightningUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.time = Float(time)
        u.flash = Float(flash)
        u.boltAlpha = Float(boltAlpha)
        u.charge = Float(charge)
        u.disturbance = Float(disturbance)
        u.ditherAmount = 1.0 / 1023.0
        u.boltCount = Int32(points.count)

        withUnsafeMutableBytes(of: &u.boltPoints) { raw in
            let buffer = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, p) in points.enumerated() where i < Int(kMaxBoltPoints) {
                buffer[i] = SIMD2(Float(p.x), Float(p.y))
            }
        }

        encoder.setFragmentBytes(&u, length: MemoryLayout<LightningUniforms>.stride, index: 0)
    }
}
