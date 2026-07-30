import CoreMotion

/// Watches how still the phone is.
///
/// Uses `userAcceleration`, which already has gravity removed, so a phone lying
/// on a desk reads near zero regardless of which way up it is. No authorisation
/// is required for raw device motion, so the app asks for nothing.
@MainActor
final class MotionMonitor {

    /// Smoothing on the incoming magnitude. Heavy, because a single sample
    /// spike from a door closing should not empty someone's bottle.
    private static let smoothing: Double = 0.82

    private let manager = CMMotionManager()

    /// 0 when perfectly still. A phone on a desk sits around 0.005 to 0.02, a
    /// hand picking it up goes well past 0.2.
    private(set) var agitation: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let a = motion.userAcceleration
                let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                self.agitation = self.agitation * Self.smoothing
                    + magnitude * (1 - Self.smoothing)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
