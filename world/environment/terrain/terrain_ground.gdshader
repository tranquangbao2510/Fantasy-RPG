// Nền đất vẽ tay, chiếu lên mặt phẳng đất isometric 2:1 (TASK VISUAL-02).
// Texture vẽ top-down (nhìn thẳng xuống) được lấy mẫu theo toạ độ lưới (i, j) của mặt đất nên trên màn hình
// bị nén dọc 2:1 và xoay 45° — đúng phép chiếu (viên đá vuông → hình thoi).
// Chống lặp: trộn hai lần lấy mẫu (lệch tỉ lệ/góc) theo noise tần số thấp + tông màu vĩ mô. anti_tiling = 0 tắt
// (dùng cho đá lát có lưới đều).
shader_type canvas_item;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
/// Số tile lưới (64×32) mà một lần lặp texture phủ theo mỗi trục.
uniform float tiles_per_texture = 6.0;
uniform float anti_tiling = 1.0;
uniform vec4 tint_a : source_color = vec4(1.0);
uniform vec4 tint_b : source_color = vec4(0.92, 0.95, 0.82, 1.0);
uniform float macro_scale = 40.0;
uniform float blend_scale = 20.0;

varying vec2 grid;
// Màu đỉnh (modulate/vertex color). Không dùng COLOR trong fragment vì nó đã nhân sẵn mẫu TEXTURE theo UV mặc định.
varying vec4 vertex_color;

vec2 to_grid(vec2 p) {
	return vec2(p.x / 64.0 + p.y / 32.0, p.y / 32.0 - p.x / 64.0);
}

void vertex() {
	grid = to_grid((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
	vertex_color = COLOR;
}

void fragment() {
	vec2 uv1 = grid / tiles_per_texture;
	float a = 0.7;
	vec2 uv2 = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * grid / (tiles_per_texture * 1.37) + vec2(0.31, 0.17);
	float m = smoothstep(0.35, 0.65, texture(macro_noise, grid / blend_scale).r) * anti_tiling;
	vec4 c = mix(texture(albedo, uv1), texture(albedo, uv2), m);
	float t = smoothstep(0.3, 0.75, texture(macro_noise, grid / macro_scale + vec2(0.5)).r);
	c.rgb *= mix(tint_a.rgb, tint_b.rgb, t);
	COLOR = vec4(c.rgb, c.a) * vertex_color;
}
