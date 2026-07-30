import MetalKit
import simd

/// Genies in a Bottle. Paid.
///
/// Genies arrive while the phone is left alone and busy themselves with work
/// nobody can quite make out. Moving the phone is an earthquake, and some of
/// them flee.
///
/// The behaviour here is real; the way a genie looks is not finished. They are
/// currently soft flames with a suggestion of form, which is enough to judge
/// the loop but nowhere near enough to sell the environment.
final class GenieWorld: Environment {

    let title = "Genies in a Bottle"
    let fragmentFunction = "genies_fragment"
    let isPaid = true

    /// How long a genie takes to fade in on arrival, and out when it flees.
    private static let fadeSeconds: Double = 1.6

    /// Fraction of the population that leaves per earthquake. Deliberately not
    /// all of them: losing everything makes a disturbance feel like a reset
    /// rather than a cost.
    private static let fleeFraction: Double = 0.28

    private struct Genie {
        var position: SIMD2<Double>
        var target: SIMD2<Double>
        var phase: Double
        var alpha: Double
        var fleeing: Bool
        /// How long until it wanders somewhere else.
        var restless: Double
    }

    private var genies: [Genie] = []
    private var time: Double = 0
    private var shake: SIMD2<Double> = .zero
    private var shakeEnergy: Double = 0

    func update(delta: Double, charge: Double, disturbance: Double) {
        time += delta

        // Decaying random walk, so the earthquake rattles rather than slides.
        shakeEnergy = max(0, shakeEnergy - delta * 2.2)
        shake = SIMD2(Double.random(in: -1...1), Double.random(in: -1...1))
            * shakeEnergy * 0.045

        let wanted = Int((Double(kMaxGenies) * charge).rounded())
        let settled = genies.filter { !$0.fleeing }.count

        if settled < wanted, genies.count < Int(kMaxGenies) {
            genies.append(spawn())
        }

        for i in genies.indices {
            var g = genies[i]

            let target: Double = g.fleeing ? 0 : 1
            g.alpha += (target - g.alpha) * min(delta / Self.fadeSeconds, 1)

            // Ambiguous work: drift toward somewhere, arrive, pick somewhere
            // else. Never explained, because explaining it would ruin it.
            g.restless -= delta
            if g.restless <= 0 {
                g.target = SIMD2(Double.random(in: 0.12...0.88),
                                 Double.random(in: 0.14...0.86))
                g.restless = Double.random(in: 3...11)
            }

            let toward = g.target - g.position
            g.position += toward * min(delta * 0.22, 1)
            g.phase += delta * (0.6 + 0.5 * sin(g.phase))

            genies[i] = g
        }

        genies.removeAll { $0.fleeing && $0.alpha < 0.02 }
    }

    func disturbed() {
        shakeEnergy = 1

        let staying = genies.filter { !$0.fleeing }
        let leaving = Int((Double(staying.count) * Self.fleeFraction).rounded(.up))
        guard leaving > 0 else { return }

        for index in genies.indices.shuffled() where !genies[index].fleeing {
            genies[index].fleeing = true
            if genies.filter({ $0.fleeing }).count >= leaving { break }
        }
    }

    private func spawn() -> Genie {
        let at = SIMD2(Double.random(in: 0.12...0.88), Double.random(in: 0.14...0.86))
        return Genie(position: at,
                     target: at,
                     phase: Double.random(in: 0..<(2 * .pi)),
                     alpha: 0,
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

        encoder.setFragmentBytes(&u, length: MemoryLayout<GenieUniforms>.stride, index: 0)
    }
}
