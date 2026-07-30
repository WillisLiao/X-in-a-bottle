import MetalKit
import SwiftUI

/// An MTKView that reports touches in normalised space.
///
/// The idle timer is deliberately left alone in both apps: the phone should be
/// allowed to lock on its own. Holding the screen awake would be the opposite
/// of the point in Lull, and in Bottle it is the user's Guided Access session
/// that decides how long they stay, not us.
final class CanvasView: MTKView {

    var onTouch: ((SIMD2<Double>) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        report(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        report(touches)
    }

    private func report(_ touches: Set<UITouch>) {
        guard let touch = touches.first, bounds.width > 0, bounds.height > 0 else { return }
        let p = touch.location(in: self)
        onTouch?(SIMD2(Double(p.x / bounds.width), Double(p.y / bounds.height)))
    }
}

/// Owns the Metal plumbing and drives a `CanvasRenderer`.
final class CanvasCoordinator: NSObject, MTKViewDelegate {

    private let renderer: any CanvasRenderer
    private let device: MTLDevice
    private let library: MTLLibrary
    private let queue: MTLCommandQueue
    private let pixelFormat: MTLPixelFormat
    private var lastFrame: CFTimeInterval?

    /// Built on demand and kept, because a renderer may change which fragment
    /// function it wants between frames. Swiping between environments must not
    /// stall on pipeline compilation.
    private var pipelines: [String: MTLRenderPipelineState] = [:]

    @MainActor
    init?(view: MTKView, renderer: any CanvasRenderer) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary()
        else { return nil }

        self.renderer = renderer
        self.device = device
        self.library = library
        self.queue = queue
        self.pixelFormat = view.colorPixelFormat
        super.init()

        // Warm the one it starts on, so the first frame is not a compile.
        _ = pipeline(for: renderer.fragmentFunction)
    }

    private func pipeline(for name: String) -> MTLRenderPipelineState? {
        if let cached = pipelines[name] { return cached }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "canvas_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: name)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        pipelines[name] = state
        return state
    }

    @MainActor
    func touched(at point: SIMD2<Double>) {
        renderer.touched(at: point)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// MTKView drives this on the main thread, so asserting that isolation is
    /// honest: if it ever stops being true this traps rather than racing.
    func draw(in view: MTKView) {
        MainActor.assumeIsolated { render(in: view) }
    }

    @MainActor
    private func render(in view: MTKView) {
        let now = CACurrentMediaTime()
        // Clamped so a long stall cannot teleport the world forward.
        let delta = min(now - (lastFrame ?? now), 1.0 / 8.0)
        lastFrame = now

        renderer.advance(by: delta, drawableSize: view.drawableSize)

        guard let pipeline = pipeline(for: renderer.fragmentFunction),
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        encoder.setRenderPipelineState(pipeline)
        renderer.encodeUniforms(into: encoder)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()

        view.preferredFramesPerSecond = renderer.preferredFPS

        if renderer.isFinished {
            view.isPaused = true
        }
    }
}

struct MetalCanvas: UIViewRepresentable {

    let makeRenderer: @MainActor () -> (any CanvasRenderer)?

    final class Box {
        var coordinator: CanvasCoordinator?
    }

    func makeCoordinator() -> Box { Box() }

    func makeUIView(context: Context) -> CanvasView {
        let view = CanvasView(frame: .zero, device: MTLCreateSystemDefaultDevice())

        // 16-bit float in extended-linear Display P3. Half the fight against
        // banding in near-black is won here, before the dither does its part.
        // MTKView.colorspace is macOS only, so this has to go on the layer.
        view.colorPixelFormat = .rgba16Float
        if let layer = view.layer as? CAMetalLayer {
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        }

        view.framebufferOnly = true
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = 30

        guard let renderer = makeRenderer(),
              let coordinator = CanvasCoordinator(view: view, renderer: renderer)
        else { return view }

        view.delegate = coordinator
        context.coordinator.coordinator = coordinator
        view.onTouch = { [weak coordinator] point in
            MainActor.assumeIsolated { coordinator?.touched(at: point) }
        }

        return view
    }

    func updateUIView(_ uiView: CanvasView, context: Context) {}
}
