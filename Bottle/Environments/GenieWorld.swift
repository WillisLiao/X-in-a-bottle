import MetalKit
import simd

/// Genies in a Bottle. Paid.
///
/// They arrive one at a time while the phone is left alone and stay, drifting
/// between places and working at nothing in particular. Moving the phone is an
/// earthquake and some of them flee.
final class GenieWorld: Environment {

    let title = "Genies in a Bottle"
    let fragmentFunction = "genies_fragment"
    let isPaid = true

    private static let fadeSeconds: Double = 1.6

    /// Fraction that leaves per earthquake. Deliberately not all: losing
    /// everything makes a disturbance a reset rather than a cost.
    private static let fleeFraction: Double = 0.28

    private struct Genie {
        var position: SIMD2<Double>
        var target: SIMD2<Double>
        var phase: Double
        var alpha: Double
        var scale: Double
        var facing: Double
        var fleeing: Bool
        var restless: Double
    }

    private var genies: [Genie] = []
    private var time: Double = 0
    private var shake: SIMD2<Double> = .zero
    private var shakeEnergy: Double = 0
    private var sinceSpawn: Double = 0

    var onArrive: (() -> Void)?

    func update(delta: Double, charge: Double, disturbance: Double) {
        time += delta

        // Decaying random walk, so an earthquake rattles rather than slides.
        shakeEnergy = max(0, shakeEnergy - delta * 2.2)
        shake = SIMD2(Double.random(in: -1...1), Double.random(in: -1...1))
            * shakeEnergy * 0.040

        let wanted = Int((Double(kMaxGenies) * charge).rounded())
        let held = genies.filter { !$0.fleeing }.count

        sinceSpawn += delta
        if held < wanted, sinceSpawn > 1.6, genies.count < Int(kMaxGenies) {
            genies.append(spawn())
            sinceSpawn = 0
            onArrive?()
        }

        if held > wanted, let index = genies.firstIndex(where: { !$0.fleeing }) {
            genies[index].fleeing = true
        }

        for i in genies.indices {
            var g = genies[i]

            let target: Double = g.fleeing ? 0 : 1
            g.alpha += (target - g.alpha) * min(delta / Self.fadeSeconds, 1)

            // Ambiguous work: drift somewhere, arrive, pick somewhere else.
            // Never explained, because explaining it would ruin it.
            g.restless -= delta
            if g.restless <= 0 {
                g.target = SIMD2(Double.random(in: 0.14...0.86),
                                 Double.random(in: 0.16...0.84))
                g.restless = Double.random(in: 4...13)
                g.facing = g.target.x > g.position.x ? 1 : -1
            }

            g.position += (g.target - g.position) * min(delta * 0.18, 1)
            g.phase += delta

            genies[i] = g
        }

        genies.removeAll { $0.fleeing && $0.alpha < 0.02 }
    }

    func disturbed() {
        shakeEnergy = 1

        let held = genies.filter { !$0.fleeing }
        let leaving = Int((Double(held.count) * Self.fleeFraction).rounded(.up))
        guard leaving > 0 else { return }

        var lost = 0
        for i in genies.indices.shuffled() where !genies[i].fleeing {
            genies[i].fleeing = true
            lost += 1
            if lost >= leaving { break }
        }
    }

    private func spawn() -> Genie {
        let at = SIMD2(Double.random(in: 0.16...0.84), Double.random(in: 0.18...0.82))
        return Genie(position: at,
                     target: at,
                     phase: Double.random(in: 0..<(2 * .pi)),
                     alpha: 0,
                     // Varied, so a crowd does not look stamped out.
                     scale: Double.random(in: 0.085...0.135),
                     facing: Bool.random() ? 1 : -1,
                     fleeing: false,
                     restless: Double.random(in: 1...6))
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double) {
        var u = GenieUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.time = Float(time)
        u.charge = Float(charge)
        u.disturbance = Float(disturbance)
        u.shake = SIMD2(Float(shake.x), Float(shake.y))
        u.ditherAmount = 1.0 / 1023.0

        let visible = Array(genies.prefix(Int(kMaxGenies)))
        u.count = Int32(visible.count)

        withUnsafeMutableBytes(of: &u.positions) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, g) in visible.enumerated() {
                b[i] = SIMD2(Float(g.position.x), Float(g.position.y))
            }
        }
        withUnsafeMutableBytes(of: &u.phases) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, g) in visible.enumerated() { b[i] = Float(g.phase) }
        }
        withUnsafeMutableBytes(of: &u.alphas) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, g) in visible.enumerated() { b[i] = Float(g.alpha) }
        }
        withUnsafeMutableBytes(of: &u.scales) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, g) in visible.enumerated() { b[i] = Float(g.scale) }
        }
        withUnsafeMutableBytes(of: &u.facings) { raw in
            let b = raw.bindMemory(to: Float.self)
            for (i, g) in visible.enumerated() { b[i] = Float(g.facing) }
        }

        encoder.setFragmentBytes(&u, length: MemoryLayout<GenieUniforms>.stride, index: 0)
    }
}
