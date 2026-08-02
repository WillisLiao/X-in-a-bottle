shader_type spatial;

// A thin world-space progress indicator.
//
// UV.x is the bearing around the shoreline, authored by `Feast._mesh`.
// The ribbon is faint all the way round so the filled portion reads as part of
// a loop, not as a stray line beside the land.

render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float breathe : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent : source_color = vec4(1.0, 0.60, 0.29, 1.0);

varying float around;

void vertex() {
	around = UV.x;
}

void fragment() {
	float ready = step(0.999, progress);
	float filled = 1.0 - smoothstep(progress - 0.012, progress + 0.003, around);

	// The distance wraps because a completed loop has no visually privileged
	// seam. A six per cent tail is obvious at a glance but calm enough not to
	// suggest motion someone could actually watch over two hours.
	float loop_distance = abs(around - progress);
	loop_distance = min(loop_distance, 1.0 - loop_distance);
	float head = 1.0 - smoothstep(0.008, 0.060, loop_distance);

	float partial = 0.10 + filled * 0.72 + head * 0.72;
	float pulse = 0.55 + 0.45 * sin(TIME * 1.3);
	float complete = mix(0.18, pulse, breathe);
	float energy = mix(partial, complete, ready);
	float emission_scale = mix(5.4 + head * 2.2, 11.0, ready);

	ALBEDO = accent.rgb * energy;
	EMISSION = accent.rgb * energy * emission_scale;
	ALPHA = clamp(0.12 + energy * 0.88, 0.0, 1.0);
}
