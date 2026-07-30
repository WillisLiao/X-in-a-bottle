import Foundation
import simd

/// The findable things in the fog.
///
/// One presence exists at a time. It is never marked and never pointed at: the
/// fog thickens faintly where it is, and the player either notices or does not.
/// Reaching it resolves it, and then it is gone. Nothing is kept.
final class PresenceField {

    /// How close the ember has to get before a presence resolves.
    static let reachDistance: Double = 0.055

    /// How long the bloom lasts before the fog closes over it.
    static let resolveSeconds: Double = 3.5

    /// Gap before the next thing appears, at the start of a session and at the
    /// end of one. The world thinning out is the structure of the game, not a
    /// difficulty curve: by the time nothing is left there is nothing to do,
    /// which is what makes letting go land.
    ///
    /// Short for now so the loop can be evaluated in a few minutes rather than
    /// twenty. Real values are longer.
    static let respawnAtStart: Double = 6
    static let respawnAtEnd: Double = 90

    /// Distance beyond which the hint is at its faintest.
    private static let hintRadius: Double = 0.42

    private(set) var position = SIMD2<Double>(0.5, 0.2)
    private(set) var resolve: Double = 0
    private(set) var isResolving = false

    /// Nil while a presence is present, otherwise seconds until the next.
    private var respawnIn: Double?

    /// Fired the instant one is reached, for haptics and sound.
    var onFound: (() -> Void)?

    init(light: SIMD2<Double> = SIMD2(0.5, 0.5)) {
        position = Self.place(awayFrom: light)
    }

    func update(delta: Double, light: SIMD2<Double>, progress: Double) {
        if isResolving {
            resolve = min(resolve + delta / Self.resolveSeconds, 1)
            if resolve >= 1 {
                isResolving = false
                resolve = 0
                let gap = Self.respawnAtStart
                    + (Self.respawnAtEnd - Self.respawnAtStart) * progress
                respawnIn = gap
            }
            return
        }

        if var waiting = respawnIn {
            waiting -= delta
            if waiting <= 0 {
                respawnIn = nil
                position = Self.place(awayFrom: light)
            } else {
                respawnIn = waiting
            }
            return
        }

        if distance(light, position) < Self.reachDistance {
            isResolving = true
            resolve = 0
            onFound?()
        }
    }

    /// True while something is out there to be found.
    var isPresent: Bool {
        respawnIn == nil
    }

    /// 0 when far away, 1 when touching it.
    func proximity(to light: SIMD2<Double>) -> Double {
        guard isPresent else { return 0 }
        let d = distance(light, position)
        return max(0, 1 - d / Self.hintRadius)
    }

    /// Placed far enough away that it has to be travelled to, and inset from
    /// the edges so it never hides behind the bezel.
    private static func place(awayFrom light: SIMD2<Double>) -> SIMD2<Double> {
        for _ in 0..<32 {
            let candidate = SIMD2(Double.random(in: 0.14...0.86),
                                  Double.random(in: 0.12...0.88))
            if distance(candidate, light) > 0.35 { return candidate }
        }
        return SIMD2(1 - light.x, 1 - light.y)
    }
}
