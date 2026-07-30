import MetalKit
import simd

/// Ice in a Bottle. Paid.
///
/// Blocks of ice form one after another and stay. Moving the phone melts some
/// of them away.
final class IceWorld: Environment {

    let title = "Ice in a Bottle"
    let fragmentFunction = "ice_fragment"
    let isPaid = true

    /// How long a block takes to form, and to melt away.
    private static let fadeSeconds: Double = 1.4

    /// Fraction melted per disturbance.
    private static let lossFraction: Double = 0.30

    private struct Block {
        var center: SIMD2<Double>
        var size: SIMD2<Double>
        var rotation: Double
        var alpha: Double
        var melting: Bool
    }

    private var blocks: [Block] = []
    private var time: Double = 0
    private var melt: Double = 0
    private var sinceSpawn: Double = 0

    var onForm: (() -> Void)?

    let capacity = Int(kMaxBlocks)

    func update(delta: Double, population: Int, charge: Double, disturbance: Double) {
        time += delta
        melt = max(0, melt - delta * 1.1)

        let wanted = min(population, capacity)
        let held = blocks.filter { !$0.melting }.count

        sinceSpawn += delta
        if held < wanted, sinceSpawn > 1.0, blocks.count < Int(kMaxBlocks) {
            blocks.append(makeBlock())
            sinceSpawn = 0
            onForm?()
        }

        if held > wanted, let index = blocks.firstIndex(where: { !$0.melting }) {
            blocks[index].melting = true
        }

        for i in blocks.indices {
            let target: Double = blocks[i].melting ? 0 : 1
            blocks[i].alpha += (target - blocks[i].alpha)
                * min(delta / Self.fadeSeconds, 1)
        }

        blocks.removeAll { $0.melting && $0.alpha < 0.02 }
    }

    func disturbed() {
        melt = 1

        let held = blocks.filter { !$0.melting }
        let leaving = Int((Double(held.count) * Self.lossFraction).rounded(.up))
        guard leaving > 0 else { return }

        var lost = 0
        for i in blocks.indices.shuffled() where !blocks[i].melting {
            blocks[i].melting = true
            lost += 1
            if lost >= leaving { break }
        }
    }

    /// Blocks settle toward the bottom, because ice in a vessel would. The
    /// first ones sit low and later ones stack above them.
    private func makeBlock() -> Block {
        let depth = Double(blocks.count) / Double(kMaxBlocks)
        let y = 0.92 - depth * 0.62 + Double.random(in: -0.06...0.06)

        return Block(center: SIMD2(Double.random(in: 0.16...0.84),
                                   min(max(y, 0.10), 0.94)),
                     size: SIMD2(Double.random(in: 0.075...0.135),
                                 Double.random(in: 0.055...0.100)),
                     rotation: Double.random(in: -0.6...0.6),
                     alpha: 0,
                     melting: false)
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

        let visible = Array(blocks.prefix(Int(kMaxBlocks)))
        u.count = Int32(visible.count)

        withUnsafeMutableBytes(of: &u.centers) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, k) in visible.enumerated() {
                b[i] = SIMD2(Float(k.center.x), Float(k.center.y))
            }
        }
        withUnsafeMutableBytes(of: &u.sizes) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, k) in visible.enumerated() {
                b[i] = SIMD2(Float(k.size.x), Float(k.size.y))
            }
        }
        withUnsafeMutableBytes(of: &u.rotations) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, k) in visible.enumerated() { b[i] = Float(k.rotation) }
        }
        withUnsafeMutableBytes(of: &u.alphas) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, k) in visible.enumerated() { b[i] = Float(k.alpha) }
        }

        encoder.setFragmentBytes(&u, length: MemoryLayout<IceUniforms>.stride, index: 0)
    }
}
