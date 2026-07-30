import MetalKit
import simd

/// Something that draws itself as a single full-screen fragment shader.
///
/// The canvas owns the device, queue, pipeline and frame loop, so a renderer is
/// only ever logic plus a uniform struct. Both apps here are one shader over one
/// triangle, and the parts that are easy to get wrong - the extended-linear P3
/// drawable, the overshooting fullscreen triangle, the dither, the frame pacing
/// - live in the canvas instead of being written twice and diverging.
@MainActor
protocol CanvasRenderer: AnyObject {

    /// Fragment function in the target's default Metal library.
    var fragmentFunction: String { get }

    /// Advance the world. Called once per frame, before encoding.
    func advance(by delta: Double, drawableSize: CGSize)

    /// Bind this renderer's own uniform struct at fragment buffer 0.
    func encodeUniforms(into encoder: MTLRenderCommandEncoder)

    /// A touch in normalised view space, origin top left.
    func touched(at point: SIMD2<Double>)

    /// Frames per second wanted right now. Low is good: ProMotion goes to 10Hz,
    /// and both of these apps are watched in the dark rather than played fast.
    var preferredFPS: Int { get }

    /// True once there is nothing left to draw and the loop can stop.
    var isFinished: Bool { get }
}
