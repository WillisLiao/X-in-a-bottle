shader_type spatial;

// The ground, and the paths worn into it.
//
// Everything about the land's colour except the paths is already in the mesh,
// one colour per vertex, put there by `Land.colour`. This shader exists for the
// one thing that cannot be baked in: where people have walked, which changes
// while you are watching and would otherwise mean rebuilding twenty thousand
// vertices every few seconds to move a shade of brown.
//
// `wear_map` is one byte per patch of ground, filled in by `Wear` as they walk
// and uploaded twice a second. Linear filtering does the rest - at this grid
// size a cell is about a footstep across, and interpolating between them is
// what turns a row of samples into a track.
//
// `specular_disabled` for the same reason `Land.material` used to say it:
// roughness one is as matte as a rough dielectric gets, and it still returns a
// broad sheen that reads as waxed across a whole hillside. Earth does not.

render_mode specular_disabled, diffuse_burley;

uniform sampler2D wear_map : hint_default_black, filter_linear;

// The colour bare ground goes when the grass has been walked off it. The
// region's own, so a path through snow and a path through jungle are not the
// same brown.
uniform vec3 earth : source_color = vec3(0.42, 0.35, 0.26);

// Half the mesh extent in x and z, so the shader can find its place in the
// wear map without being told the grid size.
uniform vec2 half_extent = vec2(8.71, 5.80);

// How far a fully worn path goes toward bare earth. A long way short of all the
// way: a track people use every day still has something growing in it, and the
// yard round a building site is scuffed rather than paved. At 0.82 a busy
// afternoon turned the whole middle of the region into one flat brown field
// with no structure left in it.
uniform float depth : hint_range(0.0, 1.0) = 0.60;

varying vec3 base_colour;
varying vec2 wear_uv;

void vertex() {
	base_colour = COLOR.rgb;
	wear_uv = VERTEX.xz / (half_extent * 2.0) + 0.5;
}

void fragment() {
	float worn = texture(wear_map, wear_uv).r;
	ALBEDO = mix(base_colour, earth, worn * depth);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
