shader_type canvas_item;
// Lớp phủ ngày/đêm (TASK M4, thay CanvasModulate + PointLight2D cộng dồn của M2): nhân màu cảnh với
// màu môi trường + ánh sáng của nguồn sáng MẠNH NHẤT tại điểm đó (max, không cộng) → nhiều nguồn sáng chồng nhau
// không cháy trắng. Toạ độ world; mỗi nguồn sáng là một hình tròn trên mặt đất (nén dọc `squash`).
render_mode blend_mul, unshaded;

const int MAX_LIGHTS = 32;

uniform vec3 ambient = vec3(1.0);
uniform int light_count = 0;
// x, y (world), bán kính (px mặt đất), inner_ratio (phần lõi sáng đều).
uniform vec4 light_shape[MAX_LIGHTS];
// rgb = màu × cường độ, a = squash (tỉ lệ dọc của mặt đất).
uniform vec4 light_tint[MAX_LIGHTS];

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 lit = vec3(0.0);
	for (int i = 0; i < light_count; i++) {
		vec4 shape = light_shape[i];
		vec4 tint = light_tint[i];
		vec2 d = world_pos - shape.xy;
		d.y /= tint.a;
		float dist = length(d) / shape.z;
		// Giống VisionLight.cover_at(): 1 trong lõi, giảm tuyến tính tới 0 ở mép.
		float cover = clamp((1.0 - dist) / max(1.0 - shape.w, 0.001), 0.0, 1.0);
		lit = max(lit, tint.rgb * cover);
	}
	COLOR = vec4(min(ambient + lit, vec3(1.0)), 1.0);
}
