shader_type canvas_item;
render_mode unshaded;
// Reuse the original pixel silhouette/alpha, with an ink-and-parchment ramp.
// The same small material is shared by world books, cards and equipment icons.
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	float light = dot(source.rgb,vec3(0.299,0.587,0.114));
	vec3 ink = vec3(0.15,0.23,0.28);
	vec3 parchment = vec3(0.79,0.76,0.60);
	vec3 paper = vec3(0.95,0.91,0.77);
	vec3 color = light < 0.23 ? ink : (light < 0.56 ? parchment : paper);
	COLOR = vec4(color,source.a)*vertex_tint;
}
