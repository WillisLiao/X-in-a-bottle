import MetalKit
import simd

/// Tree in a Bottle.
///
/// A different dynamic to the others: the objects are not scattered but
/// connected. Each branch grows out of one already there, so stillness builds a
/// structure rather than a collection, and a disturbance cuts limbs off it.
///
/// Cutting takes the outermost branches first, because losing an inner one
/// would orphan everything past it and the tree would fall apart rather than be
/// pruned.
final class TreeWorld: Environment {

    let title = "Tree in a Bottle"
    let fragmentFunction = "tree_fragment"
    let isPaid = true

    let capacity = Int(kMaxBranches)

    /// How long a branch takes to extend, and to wither when cut.
    private static let fadeSeconds: Double = 1.8

    /// Fraction cut away per disturbance.
    private static let lossFraction: Double = 0.22

    /// Branches at or beyond this depth carry foliage.
    private static let leafDepth = 3

    private struct Branch {
        var start: SIMD2<Double>
        var end: SIMD2<Double>
        var widthStart: Double
        var widthEnd: Double
        var depth: Int
        var angle: Double
        var alpha: Double
        var cut: Bool
        var phase: Double
        /// Children count, so growth spreads across the tree rather than
        /// stacking onto whichever branch happens to be first.
        var children: Int
    }

    private var branches: [Branch] = []
    private var time: Double = 0
    private var cut: Double = 0
    private var sinceGrowth: Double = 0

    var onGrow: (() -> Void)?

    init() {
        branches.append(trunk())
    }

    func update(delta: Double, population: Int, charge: Double, disturbance: Double) {
        time += delta
        cut = max(0, cut - delta * 0.9)

        let wanted = max(1, min(population, capacity))
        let held = branches.filter { !$0.cut }.count

        sinceGrowth += delta
        if held < wanted, sinceGrowth > 1.1, branches.count < capacity {
            if let sprout = grow() {
                branches.append(sprout)
                sinceGrowth = 0
                onGrow?()
            }
        }

        if held > wanted, let index = outermostLiving() {
            branches[index].cut = true
        }

        for i in branches.indices {
            let target: Double = branches[i].cut ? 0 : 1
            branches[i].alpha += (target - branches[i].alpha)
                * min(delta / Self.fadeSeconds, 1)
        }

        branches.removeAll { $0.cut && $0.alpha < 0.02 }

        // The trunk is never lost. A bottle with no tree in it at all would be
        // a punishment rather than a cost.
        if branches.isEmpty { branches.append(trunk()) }
    }

    func disturbed() {
        cut = 1

        let living = branches.filter { !$0.cut }.count
        let leaving = Int((Double(living) * Self.lossFraction).rounded(.up))
        guard leaving > 0 else { return }

        for _ in 0..<leaving {
            guard branches.filter({ !$0.cut }).count > 1,
                  let index = outermostLiving() else { break }
            branches[index].cut = true
        }
    }

    /// The living branch furthest from the trunk. Ties broken by recency, so a
    /// cut takes the newest growth, which is what pruning looks like.
    private func outermostLiving() -> Int? {
        var best: Int?
        var bestDepth = -1
        for (i, b) in branches.enumerated() where !b.cut && i != 0 {
            if b.depth >= bestDepth {
                bestDepth = b.depth
                best = i
            }
        }
        return best
    }

    private func trunk() -> Branch {
        Branch(start: SIMD2(0.5, 0.99),
               end: SIMD2(0.5, 0.72),
               widthStart: 0.030,
               widthEnd: 0.021,
               depth: 0,
               angle: -.pi / 2,
               alpha: 0,
               cut: false,
               phase: 0,
               children: 0)
    }

    /// Sprout from an existing branch, preferring ones that have not forked
    /// much yet so the tree spreads instead of growing one long whip.
    private func grow() -> Branch? {
        // Shallowest first, then least forked. Sorting by children before depth
        // always extends whichever tip is newest, so the tree grows depth-first
        // as a single whip - which is exactly what it did. Depth first in the
        // ordering means breadth first in the growing.
        let candidates = branches.indices.filter { !branches[$0].cut && branches[$0].children < 2 }
        guard let parentIndex = candidates.min(by: {
            (branches[$0].depth, branches[$0].children) < (branches[$1].depth, branches[$1].children)
        }) else { return nil }

        let parent = branches[parentIndex]
        branches[parentIndex].children += 1

        // Alternate sides per parent, and flip with overall branch count too.
        // Keying only off the parent makes every first child go the same way,
        // and the tree grows as a one-sided spiral - which is exactly what it
        // did on the first run.
        let side: Double = (parent.children + branches.count) % 2 == 0 ? 1 : -1

        // Pulled back toward vertical at every level. Without this the spread
        // compounds along a limb and the outer branches end up pointing at the
        // floor.
        let spread = 0.52
        let swung = parent.angle + side * spread + Double.random(in: -0.12...0.12)
        let upright = -Double.pi / 2
        let angle = swung + (upright - swung) * 0.16

        let length = 0.20 * pow(0.80, Double(parent.depth)) * Double.random(in: 0.85...1.15)
        let end = parent.end + SIMD2(cos(angle), sin(angle)) * length

        return Branch(start: parent.end,
                      end: simd_clamp(end, SIMD2(0.05, 0.05), SIMD2(0.95, 0.99)),
                      widthStart: parent.widthEnd,
                      widthEnd: parent.widthEnd * 0.72,
                      depth: parent.depth + 1,
                      angle: angle,
                      alpha: 0,
                      cut: false,
                      phase: Double.random(in: 0..<(2 * .pi)),
                      children: 0)
    }

    func encodeUniforms(into encoder: MTLRenderCommandEncoder,
                        size: CGSize,
                        charge: Double,
                        disturbance: Double) {
        var u = TreeUniforms()
        u.resolution = SIMD2(Float(size.width), Float(size.height))
        u.time = Float(time)
        u.charge = Float(charge)
        u.disturbance = Float(disturbance)
        u.cut = Float(cut)
        u.ditherAmount = 1.0 / 1023.0

        let visible = Array(branches.prefix(capacity))
        u.count = Int32(visible.count)

        func fill<T>(_ field: inout T, _ value: (Branch) -> Float) {
            withUnsafeMutableBytes(of: &field) { raw in
                let b = raw.bindMemory(to: Float.self)
                for (i, br) in visible.enumerated() { b[i] = value(br) }
            }
        }

        withUnsafeMutableBytes(of: &u.starts) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, br) in visible.enumerated() {
                b[i] = SIMD2(Float(br.start.x), Float(br.start.y))
            }
        }
        withUnsafeMutableBytes(of: &u.ends) { raw in
            let b = raw.bindMemory(to: SIMD2<Float>.self)
            for (i, br) in visible.enumerated() {
                b[i] = SIMD2(Float(br.end.x), Float(br.end.y))
            }
        }

        fill(&u.widthStart) { Float($0.widthStart) }
        fill(&u.widthEnd) { Float($0.widthEnd) }
        fill(&u.alphas) { Float($0.alpha) }
        fill(&u.phases) { Float($0.phase) }
        fill(&u.leaves) { $0.depth >= Self.leafDepth ? Float($0.alpha) : 0 }

        encoder.setFragmentBytes(&u, length: MemoryLayout<TreeUniforms>.stride, index: 0)
    }
}
