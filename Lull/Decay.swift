import Foundation

/// The one curve.
///
/// Everything in Lull reads from here: the shader uniforms, the frame rate, and
/// the audio buses once they exist. One source of truth, so the whole app winds
/// down together instead of three subsystems each easing on their own schedule.
final class Decay {

    /// A full session, after which the world is as slow and dim as it gets.
    static let sessionSeconds: Double = 20 * 60

    /// How long after the last touch before we assume they have let go.
    /// Long enough that shifting position in bed does not trigger it.
    static let letGoSeconds: Double = 90

    /// Once they have let go, the drift continues and fades over this long.
    /// The game finishing the session for them is the entire point, so this is
    /// unhurried on purpose.
    static let fadeSeconds: Double = 180

    private(set) var elapsed: Double = 0
    private(set) var sinceTouch: Double = 0
    private(set) var isLettingGo = false

    /// 0 while they are still here, 1 once the world has gone.
    private(set) var fade: Double = 0

    var onLetGo: (() -> Void)?
    var onFadedOut: (() -> Void)?

    func advance(by delta: Double) {
        guard fade < 1 else { return }

        elapsed += delta
        sinceTouch += delta

        if !isLettingGo, sinceTouch >= Self.letGoSeconds {
            isLettingGo = true
            onLetGo?()
        }

        if isLettingGo {
            fade = min(fade + delta / Self.fadeSeconds, 1)
            if fade >= 1 { onFadedOut?() }
        }
    }

    /// Called on any touch. Deliberately does not reverse the decay: it keeps
    /// you in the session, it never winds the night back up.
    func touched() {
        sinceTouch = 0
    }

    /// 0 at the start of the session, 1 at the end of it.
    var progress: Double {
        min(elapsed / Self.sessionSeconds, 1)
    }

    var luminance: Double {
        lerp(1, 0.22, easeOut(progress, 0.6)) * (1 - fade)
    }

    var saturation: Double {
        lerp(1, 0.35, easeOut(progress, 0.5))
    }

    /// Scales how fast the world drifts. Never reaches zero, because a world
    /// that stops moving reads as broken rather than as calm.
    var timeScale: Double {
        lerp(1, 0.28, easeOut(progress, 0.7))
    }

    /// Slowing the refresh rate alongside the world is both the right power
    /// profile and the right feel. ProMotion goes down to 10Hz.
    var targetFPS: Int {
        Int((lerp(30, 10, progress)).rounded())
    }
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

/// Quick at first, then flattening, so the first minutes of the wind-down are
/// perceptible and the last ones are almost not.
private func easeOut(_ x: Double, _ curve: Double) -> Double {
    1 - pow(1 - min(max(x, 0), 1), 1 / curve)
}
