// Dải địa hình phủ (đường đất, bờ bùn) vẽ bằng Line2D (TASK VISUAL 01).
// Texture lấy theo tọa độ world nên liền mạch qua các khúc cua; mép mềm + răng cưa bằng noise
// để che ranh giới với nền cỏ. Line2D cần texture_mode = Stretch để có UV.y ∈ [0,1] theo bề ngang.
shader_type canvas_item;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_noise : filter_linear_mipmap, repeat_enable;
uniform float texture_world_size = 256.0;
uniform vec4 tint : source_color = vec4(1.0);
/// Mép bắt đầu mờ từ khoảng cách này (0 = tâm, 1 = mép).
uniform float edge_start = 0.55;
uniform float edge_noise_strength = 0.35;
uniform float edge_noise_scale = 90.0;
/// Viền tối nhẹ (đất nén / ẩm) ngay trước mép.
uniform float rim_darken = 0.18;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float n = texture(edge_noise, world_pos / edge_noise_scale).r - 0.5;
	float e = d + n * edge_noise_strength;
	float alpha = 1.0 - smoothstep(edge_start, 1.0, e);
	vec4 c = texture(albedo, world_pos / texture_world_size) * tint;
	c.rgb *= 1.0 - rim_darken * smoothstep(edge_start - 0.3, edge_start + 0.15, e);
	COLOR = vec4(c.rgb, c.a * alpha * COLOR.a);
}
