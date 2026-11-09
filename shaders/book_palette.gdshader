shader_type canvas_item;
render_mode unshaded;
// Reuse the original pixel silhouette/alpha, with an ink-and-parchment ramp.
// The same small material is shared by world books, cards and equipment icons.
varying vec4 vertex_tint;
uniform vec4 ink_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 paper_color : source_color;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	float light = dot(source.rgb,vec3(0.299,0.587,0.114));
	vec3 ink = ink_color.rgb;
	vec3 parchment = mid_color.rgb;
	vec3 paper = paper_color.rgb;
	vec3 color = light < 0.23 ? ink : (light < 0.56 ? parchment : paper);
	COLOR = vec4(color,source.a)*vertex_tint;
}
