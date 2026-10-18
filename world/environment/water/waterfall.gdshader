// Thác nước (Polygon2D có UV 0..1): vệt nước chảy dọc + bọt ở chân. Bản mẫu; hoàn thiện ở VISUAL 03.
shader_type canvas_item;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 water_color : source_color = vec4(0.42, 0.66, 0.7, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 0.97, 1.0);
uniform float speed = 1.4;

void fragment() {
	float streak = texture(noise_tex, vec2(UV.x * 3.0, UV.y * 0.6 - TIME * speed)).r;
	float streak2 = texture(noise_tex, vec2(UV.x * 7.0 + 0.3, UV.y * 1.2 - TIME * speed * 1.6)).r;
	vec3 c = mix(water_color.rgb * 0.8, foam_color.rgb, smoothstep(0.45, 0.85, streak * 0.6 + streak2 * 0.4));
	float foam = smoothstep(0.7, 1.0, UV.y + (streak2 - 0.5) * 0.3);
	c = mix(c, foam_color.rgb, foam);
	float side = 1.0 - smoothstep(0.75, 1.0, abs(UV.x - 0.5) * 2.0 + (streak - 0.5) * 0.3);
	float top = smoothstep(0.0, 0.06, UV.y);
	COLOR = vec4(c, side * top * 0.92 * vertex_color.a);
}
