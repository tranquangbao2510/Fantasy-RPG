// Mặt nước suối (Line2D, texture_mode = Stretch): sâu ở giữa, nông + bọt ở mép, gợn sóng trôi theo flow_direction.
// Tương thích Compatibility renderer (không dùng SCREEN_TEXTURE).
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.09, 0.27, 0.33, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.28, 0.52, 0.5, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.94, 0.9, 1.0);
uniform vec2 flow_direction = vec2(-0.6, 0.45);
uniform float flow_speed = 22.0;
uniform float ripple_scale = 160.0;
uniform float edge_alpha_start = 0.82;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	vec2 flow = normalize(flow_direction) * flow_speed * TIME;
	float n1 = texture(noise_tex, (world_pos - flow) / ripple_scale).r;
	float n2 = texture(noise_tex, (world_pos - flow * 1.7) / (ripple_scale * 0.45) + vec2(0.37, 0.11)).r;
	float ripple = n1 * 0.6 + n2 * 0.4;
	float depth = 1.0 - smoothstep(0.0, 0.95, d + (ripple - 0.5) * 0.25);
	vec3 c = mix(shallow_color.rgb, deep_color.rgb, depth);
	// Ánh phản chiếu bầu trời (gợn sáng) và lấp lánh.
	c += vec3(0.16, 0.2, 0.2) * smoothstep(0.62, 0.8, ripple);
	c += vec3(0.5) * smoothstep(0.86, 0.95, n2) * (1.0 - depth * 0.5);
	// Bọt ở mép.
	float foam = smoothstep(0.62, 0.85, d + (n2 - 0.5) * 0.4);
	c = mix(c, foam_color.rgb, foam * 0.75);
	float alpha = 1.0 - smoothstep(edge_alpha_start, 1.0, d + (n1 - 0.5) * 0.2);
	COLOR = vec4(c, alpha * COLOR.a);
}
