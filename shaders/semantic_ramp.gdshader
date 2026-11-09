shader_type canvas_item;
render_mode unshaded;
uniform vec4 dark_color : source_color;
uniform vec4 main_color : source_color;
uniform vec4 light_color : source_color;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pigment = value < 0.28 ? dark_color.rgb : (value < 0.72 ? main_color.rgb : light_color.rgb);
	COLOR = vec4(pigment, source.a) * vertex_tint;
}
