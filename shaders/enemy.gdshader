/*
Rainbow outline by @Farfalk and @ThePadDev, July 2021
CC0 License (but citation is welcome <3)

Fixed for Sprite2D hframes / atlas regions: neighbor samples are clamped to
the active frame UV rect so adjacent frames cannot bleed a vertical seam.
*/

shader_type canvas_item;

uniform float line_thickness : hint_range(0, 20) = 1.0;
uniform float sin_frequency : hint_range(0.1, 2.0) = 0.5;
uniform float sin_offset : hint_range(0.0, 360.0) = 0.0;
uniform float light_offset : hint_range(0.0, 1.0) = 0.5;
// Optional override: (x, y, w, h) in UV. If w/h are 0, REGION_RECT is used.
uniform vec4 frame_uv_rect = vec4(0.0);

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;

	vec4 rect = frame_uv_rect;
	if (abs(rect.z) < 0.0001 || abs(rect.w) < 0.0001) {
		rect = REGION_RECT;
	}
	vec2 region_pos = rect.xy;
	vec2 region_size = abs(rect.zw);
	bool has_region = region_size.x > 0.0001 && region_size.y > 0.0001;
	vec2 region_min = has_region ? min(region_pos, region_pos + rect.zw) : vec2(0.0);
	vec2 region_max = has_region ? (region_min + region_size) : vec2(1.0);
	region_min += TEXTURE_PIXEL_SIZE * 0.5;
	region_max -= TEXTURE_PIXEL_SIZE * 0.5;

	vec2 o0 = UV + vec2(-size.x, 0.0);
	vec2 o1 = UV + vec2(0.0, size.y);
	vec2 o2 = UV + vec2(size.x, 0.0);
	vec2 o3 = UV + vec2(0.0, -size.y);
	vec2 o4 = UV + vec2(-size.x, size.y);
	vec2 o5 = UV + vec2(size.x, size.y);
	vec2 o6 = UV + vec2(-size.x, -size.y);
	vec2 o7 = UV + vec2(size.x, -size.y);

	float outline = 0.0;
	if (o0.x >= region_min.x && o0.x <= region_max.x && o0.y >= region_min.y && o0.y <= region_max.y) {
		outline += texture(TEXTURE, o0).a;
	}
	if (o1.x >= region_min.x && o1.x <= region_max.x && o1.y >= region_min.y && o1.y <= region_max.y) {
		outline += texture(TEXTURE, o1).a;
	}
	if (o2.x >= region_min.x && o2.x <= region_max.x && o2.y >= region_min.y && o2.y <= region_max.y) {
		outline += texture(TEXTURE, o2).a;
	}
	if (o3.x >= region_min.x && o3.x <= region_max.x && o3.y >= region_min.y && o3.y <= region_max.y) {
		outline += texture(TEXTURE, o3).a;
	}
	if (o4.x >= region_min.x && o4.x <= region_max.x && o4.y >= region_min.y && o4.y <= region_max.y) {
		outline += texture(TEXTURE, o4).a;
	}
	if (o5.x >= region_min.x && o5.x <= region_max.x && o5.y >= region_min.y && o5.y <= region_max.y) {
		outline += texture(TEXTURE, o5).a;
	}
	if (o6.x >= region_min.x && o6.x <= region_max.x && o6.y >= region_min.y && o6.y <= region_max.y) {
		outline += texture(TEXTURE, o6).a;
	}
	if (o7.x >= region_min.x && o7.x <= region_max.x && o7.y >= region_min.y && o7.y <= region_max.y) {
		outline += texture(TEXTURE, o7).a;
	}
	outline = min(outline, 1.0);

	vec4 animated_line_color = vec4(
		light_offset + sin(2.0 * 3.14159265 * sin_frequency * TIME + radians(sin_offset)),
		light_offset + sin(2.0 * 3.14159265 * sin_frequency * TIME + radians(sin_offset + 120.0)),
		light_offset + sin(2.0 * 3.14159265 * sin_frequency * TIME + radians(sin_offset + 240.0)),
		1.0
	);

	vec4 color = texture(TEXTURE, UV);
	float mask = clamp(outline - color.a, 0.0, 1.0);
	COLOR = mix(color, animated_line_color, mask);
}
