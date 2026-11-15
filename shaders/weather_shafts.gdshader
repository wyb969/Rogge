shader_type canvas_item;
render_mode unshaded;
uniform vec4 shaft_color : source_color;
uniform vec2 sun_direction = vec2(0.65, 0.76);
uniform float strength = 0.0;
uniform float clock = 0.0;
varying vec2 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 across = vec2(-sun_direction.y, sun_direction.x);
	float x = dot(world_at, across);
	// Two unequal bands avoid identical stripes; no screen texture, noise loop or blur pass.
	float broad = pow(max(0.0, sin(x * 0.039 + sin(clock * 0.13) * 0.16)), 12.0);
	float fine = pow(max(0.0, sin(x * 0.071 + 1.9)), 22.0);
	float breakup = 0.72 + 0.28 * sin(dot(world_at, sun_direction) * 0.008 + clock * 0.11);
	COLOR = vec4(shaft_color.rgb, min(0.18, (broad * 0.16 + fine * 0.055) * breakup) * strength);
}
