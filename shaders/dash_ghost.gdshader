shader_type canvas_item;
render_mode unshaded;

// Preserve the sprite silhouette, independent of its dark source RGB.
varying vec4 ghost_tint;
void vertex() {
	ghost_tint = COLOR;
}
void fragment() {
	float coverage = texture(TEXTURE, UV).a;
	COLOR = vec4(ghost_tint.rgb, ghost_tint.a * coverage);
}
