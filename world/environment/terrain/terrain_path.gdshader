// Dải địa hình phủ (đường đất, bờ bùn) — Line2D đặt trong node "mặt phẳng đất" (scale y = 0.5) nên bề rộng đúng
// theo mặt đất isometric (TASK VISUAL-02). Texture lấy theo toạ độ lưới (chiếu đúng góc), mép mềm + răng cưa bằng noise
// để che ranh giới với nền cỏ. Line2D cần texture_mode = Stretch để có UV.y ∈ [0,1] theo bề ngang.
shader_type canvas_item;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_noise : filter_linear_mipmap, repeat_enable;
uniform float tiles_per_texture = 6.0;
uniform vec4 tint : source_color = vec4(1.0);
/// Pha màu texture về phía sand_color (0 = giữ nguyên) — làm đường sáng, giảm tương phản đốm đậm (VISUAL-02.2).
uniform vec4 sand_color : source_color = vec4(0.86, 0.78, 0.6, 1.0);
uniform float sand_mix = 0.0;
/// Mép bắt đầu mờ từ khoảng cách này (0 = tâm, 1 = mép).
uniform float edge_start = 0.55;
uniform float edge_noise_strength = 0.35;
uniform float edge_noise_scale = 3.0;
/// Tỉ trọng lớp noise chi tiết (tần số × 3.3) trong mép — cỏ lấn vào đường thành vệt nhỏ.
uniform float edge_detail = 0.0;
/// Viền tối nhẹ (đất nén / ẩm) ngay trước mép.
uniform float rim_darken = 0.18;

varying vec2 grid;
// Không dùng COLOR trong fragment: nó đã nhân sẵn mẫu TEXTURE theo UV của Line2D.
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	grid = vec2(p.x / 64.0 + p.y / 32.0, p.y / 32.0 - p.x / 64.0);
}

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float n = texture(edge_noise, grid / edge_noise_scale).r - 0.5;
	float n_fine = texture(edge_noise, grid * 3.3 / edge_noise_scale + vec2(0.37, 0.61)).r - 0.5;
	float e = d + mix(n, n_fine, edge_detail) * edge_noise_strength;
	float alpha = 1.0 - smoothstep(edge_start, 1.0, e);
	vec4 c = texture(albedo, grid / tiles_per_texture);
	c.rgb = mix(c.rgb, sand_color.rgb, sand_mix) * tint.rgb;
	c.rgb *= 1.0 - rim_darken * smoothstep(edge_start - 0.3, edge_start + 0.15, e);
	COLOR = vec4(c.rgb, c.a * tint.a * alpha * vertex_color.a);
}
