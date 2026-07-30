shader_type canvas_item;

// Grain and vignette. Both deliberately quiet: enough to bind the frame
// together and take the digital cleanliness off it, not enough to read as an
// effect in its own right.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float grain : hint_range(0.0, 0.08) = 0.016;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;

// Interleaved gradient noise. Quiet enough to read as film grain rather than
// as a screen door, which is the failure mode of a plain hash.
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	float d = distance(SCREEN_UV, vec2(0.5, 0.46));
	col *= mix(1.0, smoothstep(1.02, 0.24, d), vignette);

	// Scaled by luminance so the grain sits in the mid-tones and leaves the
	// blacks clean. Grain in the shadows is what makes a dark image look noisy
	// rather than filmic.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col += (ign(FRAGCOORD.xy + TIME * 60.0) - 0.5) * grain * smoothstep(0.0, 0.35, lum);

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
