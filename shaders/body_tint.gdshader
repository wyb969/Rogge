shader_type canvas_item;

// Recolor a sprite toward one semantic hue while keeping its shading.
// Vertex color (modulate / self_modulate) still carries hurt, freeze and poison.
uniform vec3 target = vec3(0.886, 0.231, 0.231);
uniform float amount = 0.93;
uniform float lift = 0.38;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shaded = target * (lift + luma * 1.15);
	COLOR = vec4(mix(tex.rgb, shaded, clamp(amount, 0.0, 1.0)), tex.a) * COLOR;
}
