shader_type canvas_item;
render_mode unshaded;
varying vec4 pulse_tint;

void vertex() {
	pulse_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float shade = smoothstep(0.05, 0.92, dot(source.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 ink = vec3(0.055, 0.025, 0.045);
	COLOR = vec4(mix(ink, pulse_tint.rgb, shade), source.a * pulse_tint.a);
}
