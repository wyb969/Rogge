shader_type canvas_item;

uniform sampler2D ground_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_tex_size = vec2(128.0, 240.0);
uniform vec2 tile_pixel_size = vec2(16.0, 16.0);
// Base grass tile top-left in atlas pixels (tile 1,1).
uniform vec2 base_tile_offset = vec2(16.0, 16.0);
// Occasional variant tiles (tile 5,0 / 5,1).
uniform vec2 variant_a_offset = vec2(80.0, 0.0);
uniform vec2 variant_b_offset = vec2(80.0, 16.0);
uniform float world_tile_size = 16.0;
uniform vec4 tint = vec4(0.227451, 0.321569, 0.415686, 1.0);
// 0 keeps the classic multiply. Higher values recolor the tiles toward tint.
uniform float grade = 0.0;

varying vec2 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 cell = floor(v_world / world_tile_size);
	vec2 local = fract(v_world / world_tile_size);

	float h = hash21(cell);
	vec2 atlas_offset = base_tile_offset;
	if (h > 0.92) {
		atlas_offset = variant_a_offset;
	} else if (h > 0.84) {
		atlas_offset = variant_b_offset;
	}

	vec2 uv = (atlas_offset + local * tile_pixel_size) / atlas_tex_size;
	// Nudge inward a hair to avoid atlas edge bleeding.
	uv += (0.5 - local) * (0.5 / atlas_tex_size);

	vec4 tex = texture(ground_tex, uv);
	vec3 multiplied = tex.rgb * tint.rgb;
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 placed = tint.rgb * (0.35 + luma * 1.35);
	vec3 graded = mix(multiplied, placed, clamp(grade, 0.0, 1.0));
	COLOR = vec4(graded, tex.a * tint.a);
}
