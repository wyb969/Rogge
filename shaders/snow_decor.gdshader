shader_type canvas_item;
uniform float snow_cover = 0.0;
uniform vec4 snow_tint : source_color;
varying vec4 vertex_tint;
varying float local_y;
void vertex() { vertex_tint = COLOR; local_y = VERTEX.y; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * vertex_tint;
	float top = 1.0 - smoothstep(-10.0, 12.0, local_y);
	base.rgb = mix(base.rgb, snow_tint.rgb, snow_cover * (0.24 + top * 0.7));
	COLOR = base;
}
