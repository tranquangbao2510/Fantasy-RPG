# Environment Style Guide (TASK VISUAL 01)

Tài liệu ngắn cho đồ họa môi trường. Mục đánh dấu **[provisional]** là thông số chưa được xác nhận qua thử nghiệm với asset thật; có thể đổi khi có production art.

> Trạng thái hiện tại: toàn bộ art trong `world/environment/art/` là **placeholder sinh bằng code** (`tools/placeholder_art/`), không phải production art và chưa đạt mức chi tiết của ảnh tham chiếu.

## 1. Art direction

- **High-Resolution Hand-Painted 2D Fantasy**, không phải pixel art: nét cọ mềm, chất liệu rõ (lá, cỏ, đá, đất), màu phong phú nhưng hài hòa, ánh sáng và bóng đổ tạo chiều sâu.
- Môi trường tự nhiên nhiều lớp chi tiết; kiến trúc fantasy cổ, phong hóa (rêu, nứt, dây leo).
- Nhân vật nhỏ so với môi trường: Player ~28 px world cao; cây lớn 190–220 px; vách đá cao 64 px/tầng.
- Ảnh tham chiếu chỉ quyết định phong cách, không phải bản đồ cần sao chép.

## 2. Phối cảnh

- **Three-quarter / oblique:** thấy mặt trên của mọi thứ và mặt trước (hướng nam). Chiều cao được "đùn" thẳng xuống màn hình.
- Cạnh hướng nam của khối cao hiện mặt vách; cạnh hướng đông/tây gần như chỉ thấy mép (đúng phép chiếu xiên) — dùng cạnh chéo để lộ vách bên.
- Mọi object có **origin tại điểm tiếp xúc mặt đất** (sorting anchor).

## 3. Tỉ lệ asset

| Thông số | Giá trị |
|---|---|
| Tile logic | 32×32 px world (giữ nguyên của dự án) |
| Mật độ texel **[provisional]** | 2 texel / 1 px world → sprite đặt `scale = 0.5`; ở zoom 2× hiển thị 1:1 |
| Chiều cao một tầng địa hình **[provisional]** | 64 px world (2 tile) |
| Texture nền lặp | 512×512 texel (= 256×256 world), lặp liền mạch |
| Dải vách / mép / chân vách | 512×128 / 512×48 / 512×48 texel, lặp theo chiều ngang |
| Texture tối đa khuyến nghị | 2048 px mỗi chiều; background xa có thể dùng mật độ thấp hơn (valley: 1 texel = 2 px world) |

## 4. Xây dựng địa hình

Tách **logic** và **hình ảnh**:

1. **Terrain Logic** (`TerrainLogic`, TileMapLayer 32×32, ẩn khi chơi): phân loại thô từng ô (`terrain`, `elevation`), dùng cho kích thước map/MapBounds và truy vấn loại địa hình.
2. **Base ground**: một Polygon2D lớn với `terrain_ground.gdshader` — lấy mẫu texture theo tọa độ world, trộn hai lần lấy mẫu + tông màu vĩ mô để không lộ lặp; không theo lưới tile.
3. **Transitions & details**: đường đất/bờ bùn là Line2D + `terrain_path.gdshader` (mép mềm răng cưa bằng noise); `DecalScatter` rải cụm cỏ dọc mép đường/bờ nước để che ranh giới; mảng rêu/đất/lá/hoa/sỏi phủ qua nhiều tile.
4. **Collision không phụ thuộc texture**: lấy từ hình học logic (outline địa hình cao, đường tâm suối + bề rộng, shape riêng của object).

## 5. Layering (thứ tự vẽ)

| z_index | Nhóm |
|---|---|
| −100 | Scenic background (`Parallax2D`, thung lũng xa sau mép vực) |
| −20 | Ground (map container): nền, overlay, nước, cầu gỗ, decal, bóng AO chân vách — theo thứ tự node |
| −1 (tương đối) | Bóng đổ của object (con `Shadow`) |
| 0 | Entity + object tầng 0 + khối địa hình cao (Y-sort trong `EntityContainer`) |
| 4 | Chi tiết mặt đất trên tầng 1 (sàn đá tàn tích, cỏ trên plateau) |
| 10 | Entity + object tầng 1 (`tier × 10`) |
| 40 | Atmosphere (tia nắng additive, sương, bụi sáng) |
| 50 | Foreground (tán lá phía trước ở góc map) |
| 60 | Debug overlay (Terrain Logic) |

Object đứng (cây, đá, tàn tích): đặt trong `EntityContainer/Props` (Y-sort), collision chỉ ở gốc/thân. Vật cao có `OcclusionFader` làm mờ khi Player đứng phía sau.

## 6. Elevation

- **Discrete tiers** (hiện 0–1, tối đa `ElevationMap.MAX_TIERS`). Mỗi tầng một physics layer: 7 `terrain_tier_0`, 8 `terrain_tier_1`.
- `ElevatedTerrain`: outline mặt trên → tự sinh mặt vách, mép cỏ, chân vách; mỗi đoạn vách là một node Y-sort neo tại chân vách.
- `ElevatedDeck`: mặt sàn tầng cao không chặn tầng dưới (cầu đá; đường tầng 0 đi dưới gầm).
- `ElevationConnector`: cầu thang/dốc; chỉ đổi tầng qua đây; trong hành lang chỉ có lan can chặn.
- `ElevationAgent` (gắn vào Player/enemy): đổi `collision_mask` + `z_index` theo tầng.
- Quy tắc đặt: cạnh trước của khối cao phải "đơn điệu" (không có phần mặt trên khác ngay bên dưới trong khoảng 64 px); **không đặt vật cao tầng 0 mà sprite chồng lên mặt đi được của tầng 1** (thứ tự vẽ theo tầng sẽ sai).

## 7. Ánh sáng

- **Nguồn sáng chính: trên-trái (tây bắc)**; bóng đổ về dưới-phải. Mọi asset vẽ (hoặc sinh) theo hướng này.
- Ưu tiên **painted lighting** (đã vẽ sẵn trong texture) + `CanvasModulate` tông ấm nhẹ.
- 2D light chọn lọc: chỉ 1 `PointLight2D` (đá rune). Không dùng hàng loạt dynamic light.
- Tia nắng, đốm sáng mặt đất: sprite additive, alpha thấp (≤ 0.2).
- Không có day/night, weather, GI.

## 8. Lọc texture

- Root của scene vẽ tay đặt `texture_filter = Linear Mipmap`; node con kế thừa. Map pixel cũ (TestMap) vẫn `Nearest`, không đổi cấu hình toàn project.
- Camera: `GameCamera.zoom_step = 0.25` (zoom lẻ 1×–3×), không ép integer scaling; mipmap giảm shimmering khi thu nhỏ.
- Shader lấy mẫu bằng `filter_linear_mipmap, repeat_enable`.

## 9. Đặt tên

- File/thư mục `snake_case`: `tree_oak_a.png`, `ruin_pillar_broken.tscn`, `cliff_face.png`.
- Mẫu: `<loại>_<tên>[_<biến thể>]` — `tree_*`, `bush_*`, `rock_*`, `ruin_*`; texture lặp `*_base`; dải vách `cliff_face/lip/base`.
- Atlas decal: một hàng ô bằng nhau, khai báo `atlas_columns` trong `DecalScatter`.

## 10. Yêu cầu import

| Loại | Thiết lập |
|---|---|
| Mọi texture môi trường | `mipmaps/generate = true`, `process/fix_alpha_border = true` (mặc định), nén Lossless |
| Sprite có alpha | Viền trong suốt ≥ 4 texel quanh nội dung |
| Atlas | Mỗi ô có lề trong suốt ≥ 4 texel (padding chống bleeding khi lọc tuyến tính/mipmap) |
| Texture lặp | Phải liền mạch ở mép; kích thước lũy thừa 2 **[provisional]** |
| Overlay mềm (bóng, mảng rêu, sương) | Alpha về 0 hoàn toàn trước mép ảnh |

## 11. Asset cần thay bằng production art

Toàn bộ thư mục `world/environment/art/` — đặc biệt: cây (tán lá còn đơn giản), mặt vách đá, tàn tích (khối hình học), cầu đá, cầu thang, nước/thác nước (shader cơ bản; thác hoàn thiện ở VISUAL 03), background xa, foreground.
