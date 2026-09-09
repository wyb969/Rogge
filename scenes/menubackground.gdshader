shader_type canvas_item;

// enable/disable rotation
#define USE_ROTATION 1

// enable/disable color modulation
#define USE_COLOR_MODULATION 1

uniform float g_random_seed = 0.0;
uniform vec2 g_grid_size = vec2(16.0, 9.0); // x=cols, y=rows (16 and 9 are good values for a full screen rect in 16:9 aspect ratio display)
uniform vec2 g_cell_offset = vec2(0.0, 0.0);
uniform vec2 g_speed = vec2(0.0, 0.0);
uniform float g_draw_size_min : hint_range(0.0, 1.0) = 0.1; // value between 0 and 1 (avoid 0)
uniform float g_draw_size_max : hint_range(0.0, 1.0) = 0.4; // value between 0 and 1 (avoid 0)
uniform sampler2D tex_draw;

#if USE_COLOR_MODULATION
uniform vec4 g_color_a : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 g_color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
#endif

#if USE_ROTATION
const float INV_SQRT2 = 0.70710678118;
group_uniforms Rotation;
uniform float g_rot_global_speed = 1.0;
uniform float g_rot_min_speed : hint_range(0.0, 1.0) = 0.1; // value between 0 and 1
uniform float g_rot_max_speed : hint_range(0.0, 1.0) = 1.0; // value between 0 and 1
#endif

// returns a pseudo random number
float random(vec2 xy) {
    return fract(sin(dot(xy, vec2(12.9898, 78.233))) * 43758.5453);
}

#if USE_ROTATION
// taken from godotshaders :)
vec2 rotate(vec2 uv, vec2 pivot, float angle)
{
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));

	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}
#endif

vec4 draw_tile(vec4 default_color, vec2 local_uv, vec2 center, float size, float speed, vec4 color)
{
	vec2 tile_uv_map = (local_uv - center) / size + 0.5;
#if USE_ROTATION
	tile_uv_map = rotate(tile_uv_map, vec2(0.5), TIME * speed);
#endif

    if (
        tile_uv_map.x < 0.0 || tile_uv_map.x > 1.0 ||
        tile_uv_map.y < 0.0 || tile_uv_map.y > 1.0
    ) {
        return default_color;
    }

	vec4 s = texture(tex_draw, tile_uv_map);
	return s * color;
}

vec4 draw_layer(
	vec4 default_color,
	float random_seed,
	vec2 uv,
	vec2 grid_size,
	vec2 speed,
	vec2 cell_offset,
	float draw_size_min,
	float draw_size_max
#if USE_ROTATION
	,float rot_global_speed
	,float rot_min_speed
	,float rot_max_speed
#endif
#if USE_COLOR_MODULATION
	,vec4 color_a
	,vec4 color_b
#endif
) {
    vec2 grid_uv = (uv * grid_size) - (speed * TIME) + cell_offset;
    vec2 cell_num = floor(grid_uv); // cell indices
    vec2 local_pos = fract(grid_uv); // position inside the cell

	// get draw size for this cell
	vec2 random_offset = random_seed + cell_num;
#if USE_ROTATION
	float draw_size = mix(draw_size_min, min(draw_size_max, INV_SQRT2), random(random_offset));
	float edge_margin = draw_size * INV_SQRT2;
	float tile_rot_speed =
		rot_global_speed *
		(step(0.5, random(cell_num + 1.0)) * 2.0 - 1.0) * // -1 or 1 (rotation direction)
		mix(rot_min_speed, rot_max_speed, random(cell_num + 2.0)); // rotation speed
#else
	float draw_size = mix(draw_size_min, draw_size_max, random(random_offset));
	float edge_margin = draw_size * 0.5;
	float tile_rot_speed = 0.0;
#endif

	// get "random" center for this cell
	vec2 draw_center = vec2(
	    mix(edge_margin, 1.0 - edge_margin, random(cell_num + 3.0)),
	    mix(edge_margin, 1.0 - edge_margin, random(cell_num + 4.0))
	);

	// get random color
	vec4 tile_color = vec4(1.0);
#if USE_COLOR_MODULATION
	tile_color.rgb = mix(color_a.rgb, color_b.rgb, random(cell_num + 5.0));
	tile_color.a = mix(color_a.a, color_b.a, random(cell_num + 6.0));
#endif

	return draw_tile(default_color, local_pos, draw_center, draw_size, tile_rot_speed, tile_color);
}

void fragment() {
	vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
	color = draw_layer(
		color,
		g_random_seed,
		UV,
		g_grid_size,
		g_speed,
		g_cell_offset,
		g_draw_size_min,
		g_draw_size_max
#if USE_ROTATION
		,g_rot_global_speed
		,g_rot_min_speed
		,g_rot_max_speed
#endif
#if USE_COLOR_MODULATION
		,g_color_a
		,g_color_b
#endif
	);

	// draw tile
	COLOR = color;
}