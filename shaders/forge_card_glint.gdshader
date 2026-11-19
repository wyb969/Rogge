shader_type canvas_item;
render_mode unshaded;

// The pointer tilts the surface normal relative to a fixed warm key light and cool fill.
uniform vec2 tilt = vec2(0.0);
void fragment() {
	vec2 uv = (floor(UV * vec2(64.0, 88.0)) + 0.5) / vec2(64.0, 88.0);
	vec2 pos = uv * 2.0 - 1.0;
	vec2 edge = min(uv, 1.0 - uv);
	vec3 normal = normalize(vec3(tilt * 0.56 + pos * 0.32, 1.0));
	vec3 reflected = reflect(vec3(0.0, 0.0, -1.0), normal);
	float highlight = pow(max(dot(reflected, normalize(vec3(-0.45, -0.55, 1.0))), 0.0), 8.0);
	float band = 1.0 - smoothstep(0.02, 0.31, abs(pos.x + pos.y * 0.5 + dot(tilt, vec2(0.94, 0.64))));
	float rim = 1.0 - smoothstep(0.014, 0.036, min(edge.x, edge.y));
	float intensity = floor((0.12 * band + 0.28 * highlight + rim * (0.14 + 0.24 * highlight)) * 32.0) / 32.0;
	vec3 tint = mix(vec3(0.48, 0.66, 1.0), vec3(1.0, 0.88, 0.64), highlight + 0.15 * band);
	COLOR = vec4(tint, intensity);
}
