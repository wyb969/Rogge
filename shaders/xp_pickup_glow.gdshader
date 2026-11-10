shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 bar_size = vec2(200.0,30.0);
uniform float fill_ratio = 0.0;
uniform float energy = 0.0;
uniform float tone = 0.0;
uniform float heat = 0.0;
uniform float kick = 0.0;
float box_distance(vec2 p,vec2 half_size,float r) {
	vec2 q = abs(p)-half_size+vec2(r);
	return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r;
}
void fragment() {
	vec2 p = UV*(bar_size+vec2(20.0,32.0))-vec2(10.0,22.0);
	float width = max(3.0,(bar_size.x-4.0)*fill_ratio);
	vec2 center = vec2(2.0+width*0.5,bar_size.y*0.5);
	float d = box_distance(p-center,vec2(width*0.5,max(2.0,bar_size.y*0.5-2.0)),min(3.0,width*0.35));
	float outer = exp(-max(d,0.0)*0.65)*smoothstep(-1.0,1.0,d)*0.15;
	float rim = (1.0-smoothstep(0.0,1.5,abs(d)))*(0.25+kick*0.13);
	// Bounded ribbons move inside the actual fill; the percentage stays readable.
	float ribbon = pow(max(0.0,sin(p.x*0.16-TIME*12.0+p.y*0.28)),7.0);
	float flow = ribbon*(1.0-smoothstep(-1.0,0.0,d))*0.11*heat;
	float across = smoothstep(1.0,4.0,p.x)*(1.0-smoothstep(width,width+3.0,p.x));
	float flame_height = (3.0+heat*14.0)*(0.55+0.23*sin(p.x*0.24-TIME*13.0)+0.18*sin(p.x*0.47+TIME*9.0));
	float above = max(0.0,2.0-p.y);
	float flame = across*smoothstep(0.0,2.0,above)*(1.0-smoothstep(flame_height*0.3,flame_height,above));
	flame *= (0.12+heat*0.24)*(0.65+kick*0.35)*smoothstep(0.05,0.3,heat);
	float sparks = 0.0;
	// Four analytic embers; no particle nodes, framebuffer reads or textures.
	for (int i=0;i<4;i++) {
		float f = float(i);
		float life = fract(TIME*(0.85+heat*0.7)+f*0.27);
		vec2 at = vec2(2.0+fract(f*0.381+0.17)*width,1.0-life*(8.0+heat*11.0));
		at.x += sin(life*5.0+f*2.1)*2.0;
		sparks += (1.0-smoothstep(0.4,1.5,length(p-at)))*(1.0-life)*heat*0.25;
	}
	vec3 edge_color = mix(vec3(0.45,0.88,0.93),vec3(1.0,0.86,0.42),tone);
	edge_color = mix(edge_color,vec3(1.0,0.64,0.23),heat*0.6);
	vec3 fire_color = mix(vec3(1.0,0.32,0.08),vec3(1.0,0.89,0.38),clamp(1.0-above/18.0,0.0,1.0));
	float base = outer+rim+flow;
	float total = base+flame+sparks;
	vec3 color = (edge_color*base+fire_color*flame+vec3(1.0,0.94,0.6)*sparks)/max(total,0.001);
	COLOR = vec4(color,min(0.58,total*energy));
}
