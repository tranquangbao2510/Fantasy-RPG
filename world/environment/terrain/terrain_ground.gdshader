// Nền đất vẽ tay theo tọa độ world (TASK VISUAL 01).
// Chống lặp texture: trộn hai lần lấy mẫu (tỉ lệ + góc xoay khác nhau) theo noise tần số thấp,
// cộng tông màu vĩ mô (vùng tươi / vùng khô). Không phụ thuộc lưới tile.
shader_type canvas_item;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
/// Kích thước world (px) của một lần lặp texture (512 texel / mật độ 2 = 256).
uniform float texture_world_size = 256.0;
uniform vec4 tint_a : source_color = vec4(1.0);
uniform vec4 tint_b : source_color = vec4(0.92, 0.95, 0.82, 1.0);
uniform float macro_scale = 1400.0;
uniform float blend_scale = 700.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv1 = world_pos / texture_world_size;
	float a = 0.7;
	vec2 uv2 = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * world_pos / (texture_world_size * 1.37) + vec2(0.31, 0.17);
	float m = smoothstep(0.35, 0.65, texture(macro_noise, world_pos / blend_scale).r);
	vec4 c = mix(texture(albedo, uv1), texture(albedo, uv2), m);
	float t = smoothstep(0.3, 0.75, texture(macro_noise, world_pos / macro_scale + vec2(0.5)).r);
	c.rgb *= mix(tint_a.rgb, tint_b.rgb, t);
	COLOR = vec4(c.rgb, 1.0) * COLOR;
}
