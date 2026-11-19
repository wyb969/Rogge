shader_type canvas_item;
render_mode unshaded;

uniform bool amber = false;

void fragment() {
	// Quantize the engraving so bevels and traveling highlights retain pixel edges.
	vec2 grid = vec2(56.0, 76.0);
	vec2 px = floor(UV * grid);
	vec2 edge = min(px, grid - 1.0 - px);
	float rim = min(edge.x, edge.y);
	float cut = edge.x + edge.y;
	float bevel = 1.0 - step(1.0, abs(cut - 7.0));
	float band = 1.0 - smoothstep(0.0, 0.17, abs(fract(px.x / 85.0 + px.y / 128.0 - TIME * 0.23) - 0.5));
	vec3 dark = amber ? vec3(0.26, 0.12, 0.035) : vec3(0.22, 0.08, 0.20);
	vec3 metal = amber ? vec3(1.0, 0.60, 0.17) : vec3(0.95, 0.48, 0.75);
	vec3 light = amber ? vec3(1.0, 0.94, 0.66) : vec3(1.0, 0.88, 1.0);
	float corners = (1.0 - step(11.0, cut)) * (1.0 - step(2.0, rim));
	float engraving = max(bevel, corners);
	if (amber) {
		engraving = max(engraving, (1.0 - step(1.0, abs(rim - 2.0))) * (1.0 - step(17.0, cut)));
	} else {
		vec2 jewel = abs(vec2(px.x - 28.0, edge.y - 2.0));
		engraving = max(engraving, 1.0 - step(3.0, jewel.x + jewel.y));
	}
	float border = 1.0 - step(1.0, rim);
	float foil = max(border * 0.7, engraving);
	float facets = 1.0 - smoothstep(0.0, 22.0, cut);
	vec3 base = mix(dark, metal, 0.16 * facets + 0.10 * band);
	vec3 color = mix(base, mix(metal, light, 0.26 + 0.74 * band), foil);
	COLOR = vec4(color, mix(0.53, 0.94, foil) * step(2.0, cut));
}
