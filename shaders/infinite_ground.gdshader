shader_type canvas_item;

uniform sampler2D painted_ground : source_color, filter_nearest, repeat_disable;
// First and last texel centers within the tileable interior of the painting.
uniform vec4 painted_region_px = vec4(38.0, 60.0, 860.0, 530.0);
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
// Minimum brightness and texture span are set by the shared visual style.
uniform vec2 ground_values = vec2(0.84,0.24);
// Weather lighting affects scenery only. Default values retain the menu/test
// palette; the multiplier never brightens past the established contrast bound.
uniform vec3 ambient_light = vec3(1.0);
uniform vec2 sun_direction = vec2(0.9, 0.35);
uniform float sun_strength = 0.0;
uniform float cloud_strength = 0.0;
uniform float environment_time = 0.0;
// Stage 1 uses a stronger edge darkening. 0 leaves the menu/test look unchanged.
uniform float vignette = 0.0;
uniform float snow_cover = 0.0;
uniform float ice_cover = 0.0;
uniform vec2 ice_view_position = vec2(0.0);
uniform vec2 ice_view_tilt = vec2(0.0);
uniform float ice_gloss_strength = 1.0;
uniform vec4 ice_tint : source_color;
uniform vec4 ice_reflection_tint : source_color;
uniform vec4 snow_tint : source_color;

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
	// Narrow value range: scenery keeps texture without competing with actors.
	vec3 placed = tint.rgb * (ground_values.x + luma * ground_values.y);
	vec3 graded = mix(multiplied, placed, clamp(grade, 0.0, 1.0));
	// Reflect each axis at the center of its edge texel. Both sides of a join
	// sample the same pixel, including at four-way corners and negative world positions.
	vec2 span = painted_region_px.zw - painted_region_px.xy;
	vec2 phase = v_world * 1.8 / span + 0.5; // Original art density: 900 texels / 500 world units.
	vec2 mirrored = 1.0 - abs(mod(phase, 2.0) - 1.0);
	vec2 pixel = painted_region_px.xy + mirrored * span + 0.5;
	vec3 painted = texture(painted_ground, pixel / vec2(textureSize(painted_ground, 0))).rgb;
	graded = mix(graded, painted * 0.76 + tint.rgb * 0.24, 0.88);
	if (snow_cover > 0.0) {
		float grain = hash21(floor(v_world / 3.0));
		float drift = 0.5 + 0.5 * sin(v_world.x * 0.013 + sin(v_world.y * 0.017));
		vec3 snow = snow_tint.rgb * (0.93 + grain * 0.04 + luma * 0.03);
		graded = mix(graded, snow, snow_cover * (0.85 + drift * 0.12));
	}
	if (ice_cover > 0.0) {
		float grain = hash21(floor(v_world / 4.0));
		// A planar mirror's highlight depends on the observer, never a scrolling wave texture.
		vec3 view = normalize(vec3((ice_view_position-v_world)*0.0035+ice_view_tilt*0.30,1.0));
		vec3 light_dir = normalize(vec3(-0.48,-0.65,1.0));
		vec3 half_vector = normalize(view+light_dir);
		float specular = pow(max(half_vector.z,0.0),56.0);
		// One broad sky reflection in angular space; no tiled bands or animated UV distortion.
		vec2 sky = (view.xy-vec2(0.20,-0.12))*vec2(2.0,4.5);
		float sky_glint = 1.0-smoothstep(0.1,1.2,dot(sky,sky));
		vec3 ice = ice_tint.rgb*(0.76+grain*0.018);
		ice += ice_reflection_tint.rgb*0.28*(specular+sky_glint*0.28)*ice_gloss_strength;
		graded = mix(graded, ice, ice_cover*0.94);
	}
	vec3 light = clamp(ambient_light, vec3(0.0), vec3(1.0));
	if (sun_strength > 0.0) {
		float coordinate = dot(v_world, sun_direction) * 0.028 + environment_time * 0.035;
		float rays = smoothstep(0.72, 0.98, 0.5 + 0.5 * sin(coordinate));
		light = clamp(light + vec3(0.9, 0.8, 0.55) * sun_strength * rays, vec3(0.0), vec3(1.0));
	}
	if (cloud_strength > 0.0) {
		float cloud = 0.5 + 0.5 * sin(dot(v_world, vec2(0.004, 0.002)) + environment_time * 0.06);
		light *= 1.0 - cloud_strength * cloud * 0.08;
	}
	if (vignette > 0.0) {
		vec2 centered = (SCREEN_UV - vec2(0.5)) * vec2(1.15, 1.0);
		float edge = smoothstep(0.22, 0.95, length(centered));
		graded *= mix(1.0, 1.0 - vignette, edge);
	}
	COLOR = vec4(graded * light, tex.a * tint.a);
}
