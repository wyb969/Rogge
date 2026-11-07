shader_type canvas_item;
render_mode unshaded;
varying vec4 pigment_color;

void vertex() {
	pigment_color = COLOR;
	float tile = floor(INSTANCE_CUSTOM.r * 11.0 + 0.5);
	UV = (UV + vec2(mod(tile, 4.0), floor(tile / 4.0))) / vec2(4.0, 3.0);
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	// A pale ink core suggests fluorescence without bloom, lights or additive fog.
	vec3 pigment = mix(pigment_color.rgb, vec3(1.0), (1.0 - ink.r) * 0.65);
	COLOR = vec4(pigment, pigment_color.a * ink.a);
}
