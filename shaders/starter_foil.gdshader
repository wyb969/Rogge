shader_type canvas_item;
render_mode unshaded;

uniform bool dimension = false;
uniform bool toon = false;
uniform vec4 toon_tint : source_color;
uniform bool crimson = false;

// A slow diagonal foil reflection. Only the machine and reel frames use it.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wave = p.x * 1.5 - p.y * 0.85 + 0.25 * sin(p.y * 4.0 + TIME * 0.8);
	float hue = wave * 0.34 + TIME * 0.13;
	vec3 spectrum = 0.55 + 0.45 * cos(6.28318 * (hue + vec3(0.0, 0.67, 0.33)));
	float glint = pow(0.5 + 0.5 * cos(wave * 6.0 - TIME * 1.8), 7.0);
	float rim = smoothstep(0.84, 0.99, max(abs(p.x), abs(p.y)));
	if (crimson) {
		float band = smoothstep(0.35, 0.96, glint);
		spectrum = mix(vec3(0.53, 0.018, 0.10), vec3(1.0, 0.17, 0.26), glint);
		spectrum = mix(spectrum, vec3(1.0, 0.78, 0.72), band * (0.35 + 0.60 * rim));
	}
	if (dimension) {
		spectrum = mix(vec3(0.50, 0.42, 0.04), vec3(1.0, 0.953, 0.416), 0.45 + 0.55 * glint);
	}
	if (toon) {
		spectrum = mix(toon_tint.rgb * 0.45, toon_tint.rgb, 0.45 + 0.55 * glint);
		spectrum = mix(spectrum, vec3(1.0), glint * rim * 0.30);
	}
	COLOR.rgb = mix(COLOR.rgb, spectrum, 0.14 + 0.23 * glint + 0.58 * rim);
	COLOR.rgb += vec3(0.13 * glint * rim);
}
