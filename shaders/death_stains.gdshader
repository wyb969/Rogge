shader_type canvas_item;
render_mode unshaded;

void vertex() {
	float tile = floor(INSTANCE_CUSTOM.r * 11.0 + 0.5);
	UV = (UV + vec2(mod(tile, 4.0), floor(tile / 4.0))) / vec2(4.0, 3.0);
}
