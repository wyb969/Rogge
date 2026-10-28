/*
Rainbow outline by @Farfalk and @ThePadDev, July 2021

Apply to canvas items with transparent backgrounds.
Check that there is sufficient transparent background space for the outline!

CC0 License (but citation is welcome <3)

Fixed: clamp neighbor samples to the current Sprite2D / spritesheet frame so
adjacent hframes do not bleed a vertical rainbow seam.
*/

shader_type canvas_item;

uniform float line_thickness : hint_range(0, 20) = 1.0;    // thickness of the line
uniform float sin_frequency : hint_range(0.1, 2.0) = 0.5;  // frequency of the rainbow
uniform float sin_offset : hint_range(0.0, 360.0) = 0.0;   // offset of the rainbow, useful to differentiate objects using the same shader
uniform float light_offset : hint_range(0.0, 1.0) = 0.5;   // this offsets all color channels; if set to 0 only red green and blue colors will be shown.
// Sprite sheet layout (Sprite2D hframes / vframes). Use (1,1) for a single image.
uniform vec2 frame_count = vec2(1.0, 1.0);

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;

	vec2 frames = max(frame_count, vec2(1.0));
	vec2 frame_size = 1.0 / frames;
	// UV is in full-texture space for Sprite2D hframes; lock sampling to this cell.
	vec2 frame_min = floor(UV / frame_size + 1e-5) * frame_size;
	vec2 frame_max = frame_min + frame_size;

	// Neighbor offsets. TEXTURE is only valid inside fragment(), so sample inline.
	vec2 o0 = UV + vec2(-size.x, 0.0);
	vec2 o1 = UV + vec2(0.0, size.y);
	vec2 o2 = UV + vec2(size.x, 0.0);
	vec2 o3 = UV + vec2(0.0, -size.y);
	vec2 o4 = UV + vec2(-size.x, size.y);
	vec2 o5 = UV + vec2(size.x, size.y);
	vec2 o6 = UV + vec2(-size.x, -size.y);
	vec2 o7 = UV + vec2(size.x, -size.y);

	float outline = 0.0;
	if (o0.x >= frame_min.x && o0.x <= frame_max.x && o0.y >= frame_min.y && o0.y <= frame_max.y) {
		outline += texture(TEXTURE, o0).a;
	}
	if (o1.x >= frame_min.x && o1.x <= frame_max.x && o1.y >= frame_min.y && o1.y <= frame_max.y) {
		outline += texture(TEXTURE, o1).a;
	}
	if (o2.x >= frame_min.x && o2.x <= frame_max.x && o2.y >= frame_min.y && o2.y <= frame_max.y) {
		outline += texture(TEXTURE, o2).a;
	}
	if (o3.x >= frame_min.x && o3.x <= frame_max.x && o3.y >= frame_min.y && o3.y <= frame_max.y) {
		outline += texture(TEXTURE, o3).a;
	}
	if (o4.x >= frame_min.x && o4.x <= frame_max.x && o4.y >= frame_min.y && o4.y <= frame_max.y) {
		outline += texture(TEXTURE, o4).a;
	}
	if (o5.x >= frame_min.x && o5.x <= frame_max.x && o5.y >= frame_min.y && o5.y <= frame_max.y) {
		outline += texture(TEXTURE, o5).a;
	}
	if (o6.x >= frame_min.x && o6.x <= frame_max.x && o6.y >= frame_min.y && o6.y <= frame_max.y) {
		outline += texture(TEXTURE, o6).a;
	}
	if (o7.x >= frame_min.x && o7.x <= frame_max.x && o7.y >= frame_min.y && o7.y <= frame_max.y) {
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
	// Only paint outline on transparent exterior pixels (avoids interior stripes).
	float mask = clamp(outline - color.a, 0.0, 1.0);
	COLOR = mix(color, animated_line_color, mask);
}
