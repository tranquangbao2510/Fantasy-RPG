# Environment Style Guide (TASK VISUAL-01 → VISUAL-02 isometric)

Tài liệu cho đồ họa môi trường. Mục **[provisional]** là thông số chưa được xác nhận bằng asset thật.

> Trạng thái: toàn bộ art trong `world/environment/art/` là **placeholder sinh bằng code** (`tools/placeholder_art/`), không phải production art. Placeholder đã **đúng góc và đúng tỉ lệ** để làm khuôn cho art thật.
>
> Map cũ `world/maps/test_map/` và `world/sandbox/` vẫn ở góc top-down/oblique cũ (pixel art, Nearest). Sẽ chuyển sang isometric ở task sau.

## 1. Art direction

- **High-Resolution Hand-Painted 2D Fantasy**, không phải pixel art: nét cọ mềm, chất liệu rõ (lá, cỏ, đá, đất), màu phong phú nhưng hài hòa, ánh sáng và bóng đổ tạo chiều sâu.
- Kiến trúc fantasy cổ, phong hóa (rêu, nứt, dây leo). Khu vực lơ lửng trên vực sâu, phía xa có núi và lâu đài mờ.
- Nhân vật nhỏ so với môi trường (xem bảng tỉ lệ).

## 2. Phối cảnh — isometric dimetric 2:1

| Thông số | Giá trị |
|---|---|
| Phép chiếu | Dimetric "pixel-art isometric" **2:1**: một ô vuông trên mặt đất thành hình thoi rộng gấp đôi cao |
| Góc cạnh lưới trên màn hình | **±26.565°** so với phương ngang (độ dốc 1:2) |
| Trục lưới | `i` → xuống-phải (đông nam), `j` → xuống-trái (tây nam). Góc trên cùng của map là bắc |
| Công thức chiếu | `x = (i − j) × 32`, `y = (i + j) × 16 − z` (i, j theo tile, z = độ cao px). Code: `IsoProjection.to_screen()` |
| Chiều cao | Đùn **thẳng xuống màn hình** (không nghiêng) |
| Mặt nhìn thấy | Mặt trên + mặt **tây nam (SW, trái-dưới)** + mặt **đông nam (SE, phải-dưới)**. Mặt NW/NE bị che |
| Di chuyển | WASD theo hướng màn hình; vận tốc dọc × 0.5 (`Player.vertical_speed_scale`) → tốc độ đều trên mặt đất, nhấn chéo đi đúng theo trục lưới |

Mọi object có **origin tại điểm chạm đất** (sorting anchor), xem mục 5.

## 3. Tỉ lệ

| Thông số | Giá trị |
|---|---|
| Tile logic | Thoi **64 × 32 px** world (cạnh thoi ≈ 35.8 px) |
| Mật độ texel **[provisional]** | 2 texel / 1 px world → sprite `scale = 0.5`; zoom 2× hiển thị 1:1 |
| Chiều cao 1 tầng | **64 px** màn hình (= 2 lần chiều cao một ô thoi) |
| Vách vực quanh map | 192 px (3 tầng), tan vào sương |
| Nhân vật placeholder | thân ~28 px cao, footprint ellipse 14 × 7 px. **Sprite nhân vật phải thấp hơn 64 px** (tầng), nếu không thứ tự vẽ với vách bị sai |
| Cây lớn | 190–230 px cao, tán rộng 150–180 px (≈ 5–8× chiều cao nhân vật) |
| Bụi | 55–90 px rộng; đá lớn ~110 px; cột tàn tích ~150 px cao, bệ 0.78 tile |
| Cầu thang | rộng 1.5 tile, chạy 1.75 tile, 7 bậc, cao 1 tầng |
| Lối đi trên vòm | 4.6 × 1.5 tile, cao 1 tầng, vòm rộng ~68 px cho lối tầng thấp đi qua |
| Texture nền lặp | 512 × 512 texel, **vẽ top-down** (nhìn thẳng xuống); shader chiếu lên mặt phẳng iso. Cỏ: 1 lần lặp = 6 tile; đá lát: 8 × 8 viên = 8 tile (1 viên = 1 tile) |
| Dải vách / mép cỏ / chân vách | 512 × 128 / 512 × 48 / 512 × 48 texel, lặp theo chiều ngang (vách cao hơn 64 px lặp theo chiều dọc) |

## 4. Xây dựng địa hình

1. **Terrain Logic** (`TerrainLogic`, TileMapLayer **isometric**, `TILE_LAYOUT_DIAMOND_DOWN`, tile 64×32, `position = (−32, 0)` để khớp công thức chiếu; ẩn khi chơi): phân loại theo **vị trí màn hình** (cái đang hiển thị ở đó) — grass / dirt / water / cliff / high / void. Kích thước map cho camera lấy từ đây (`IsoMapBounds`).
2. **Mặt đất chính** (`LandMass`, ElevatedTerrain tầng 0 nằm ngoài ElevationMap): khối đất nổi trên vực; mép SE/SW lộ vách vực 192 px, mép NW/NE có mép cỏ (`back_lip`). Tường chặn mép đất: `LandEdge` (vòng segment, layer `world`).
3. **Nền**: `terrain_ground.gdshader` lấy mẫu theo **toạ độ lưới (i, j)** → texture top-down tự nén 2:1 và xoay 45° (viên đá vuông → hình thoi). `anti_tiling = 0` cho đá lát có lưới đều.
4. **Overlay** (đường đất, bờ bùn, nước): Line2D đặt trong node **`GroundPlane` có `scale = (1, 0.5)`**, điểm Line2D là toạ độ mặt đất (y × 2) → bề rộng và khúc cua đúng trên mặt đất iso. Collision suối dựng trong cùng không gian rồi chiếu ra.
5. **Decal**: cỏ/hoa/sỏi đứng (billboard, neo tại chân); decal phẳng (rêu, bóng, đốm nắng) dùng `DecalScatter.flat_on_ground` (xoay trên mặt đất rồi nén 2:1).
6. **Collision không lấy từ texture**: outline logic, đường tâm suối + bề rộng, footprint thoi/ellipse 2:1 của object.

## 5. Layering & sorting

| z_index | Nhóm |
|---|---|
| −110 | `AbyssHaze`: nền lấp đầy màu sương vực (không bao giờ lộ khoảng trống) |
| −100 | Scenic background (`Parallax2D`: trời, núi, lâu đài mờ, rừng thung lũng, tan vào sương) |
| −20 | Ground: mặt đất + vách vực, overlay, nước, cầu gỗ, decal, bóng AO, thác + sương vực |
| −1 (tương đối) | Bóng đổ của object |
| 0 | Entity + object tầng 0 + khối địa hình cao (Y-sort) |
| 4 | Chi tiết mặt đất tầng 1 (quảng trường đá, đường đất trên plateau, cỏ) |
| 10 | Entity + object tầng 1 (`tier × 10`) |
| 40 / 50 / 60 | Atmosphere / Foreground / Debug overlay |

**Quy tắc neo sorting cho khối lớn (isometric):**

- Object nhỏ (cây, bụi, đá, cột): một anchor = điểm chạm đất (gốc cây, đỉnh dưới của bệ).
- Vách khối cao: `ElevatedTerrain` chia vách thành đoạn ≤ 32 px, mỗi đoạn neo tại **điểm chân vách cao nhất (y nhỏ nhất) của đoạn**.
- Vật dài chạy chéo (lối đi trên vòm, cầu thang, vòm, tường): `FootprintSortedSprite` cắt ảnh thành lát dọc 16 px, mỗi lát neo tại **mép trước của footprint** (y lớn nhất của polygon chân vật tại giữa lát). Node cha phải bật `y_sort_enabled`.
- Mặt trên khối cao: neo tại y lớn nhất của outline.

## 6. Elevation

- **Discrete tiers** (0–1). Physics layer: 7 `terrain_tier_0`, 8 `terrain_tier_1`. `z = tier × 10`.
- `ElevatedTerrain.outline` = mặt trên trên màn hình = footprint lưới chiếu với `z = 64`. Footprint dưới đất = outline + (0, 64). Vùng tầng 0 bị chặn = mặt trên ∪ vách (quét outline xuống 64 px).
- `ElevatedDeck.deck_polygon`: mặt đi được tầng cao không chặn tầng dưới (lối đi trên vòm).
- `ElevationConnector`: hình bình hành `bottom → top` + `half_width` (song song cạnh vách), cầu thang đi theo trục chéo; chỉ đổi tầng qua đây.
- Quy tắc đặt: cạnh trước khối cao "đơn điệu"; **vật cao tầng 0 phải cách cạnh trước khối cao đủ xa** để sprite không chồng lên mặt đi được của tầng 1 (cây lớn: ≥ 9 bước `i + j` trước cạnh vách).

## 7. Ánh sáng

- **Nguồn sáng chính: trên-trái màn hình** (giữ như VISUAL-01). Độ sáng mặt: **trên 1.15 > SW 0.95 > SE 0.66** (hệ số so với màu gốc).
- Bóng đổ: ellipse 2:1 trên mặt đất, lệch **xuống-phải** (≈ +14% bề ngang sang phải, +4% xuống).
- Painted lighting + `CanvasModulate` ấm nhẹ; 1 `PointLight2D` (đá rune); tia nắng additive alpha ≤ 0.1.

## 8. Lọc texture

- Root scene vẽ tay: `texture_filter = Linear Mipmap`. Camera `zoom_step = 0.25` (1×–3×), không ép integer scaling.
- Shader dùng `filter_linear_mipmap, repeat_enable`. **Lưu ý (Compatibility):** node gán cùng texture vào `texture` và vào uniform shader sẽ dùng chung trạng thái sampler → phải bật `texture_repeat` trên node hoặc không gán `texture`. Trong fragment không nhân với `COLOR` (đã gồm mẫu TEXTURE theo UV mặc định) — lấy màu đỉnh qua varying.

## 9. Đặt tên

- `snake_case`: `tree_oak_a.png`, `ruin_pillar_broken.tscn`, `cliff_face.png`; mẫu `<loại>_<tên>[_<biến thể>]`.
- Atlas decal: một hàng ô bằng nhau, khai báo `atlas_columns`.

## 10. Yêu cầu import

| Loại | Thiết lập |
|---|---|
| Mọi texture môi trường | `mipmaps/generate = true`, `fix_alpha_border = true`, Lossless |
| Sprite có alpha | Viền trong suốt ≥ 4 texel quanh nội dung |
| Atlas | Mỗi ô có lề trong suốt ≥ 4 texel |
| Texture lặp | Liền mạch ở mép; kích thước lũy thừa 2 **[provisional]** |
| Overlay mềm | Alpha về 0 trước mép ảnh |

## 11. Hướng dẫn gen art bằng AI

Dùng kèm ảnh placeholder tương ứng trong `world/environment/art/` làm **khuôn góc/tỉ lệ** (image-to-image hoặc ControlNet depth/lineart), rồi chỉnh tay.

**Prompt chung (tiếng Anh, thêm vào mọi asset):**

> hand-painted 2D fantasy game asset, isometric view, 2:1 dimetric projection, camera looking from the south, ground grid edges at 26.57 degrees, vertical edges perfectly vertical, soft painterly brushwork, rich but harmonious colors, sunlight from the upper left, cast shadow toward the lower right, top faces brightest, left (south-west) faces medium, right (south-east) faces darkest, isolated on fully transparent background, no ground plane, no text, no border

**Prompt phủ định:** `pixel art, perspective distortion, vanishing point, top-down, side view, front view, tilted verticals, multiple light sources, harsh outlines, background scenery, cropped`

| Loại | Kích thước xuất (texel) | Neo / yêu cầu riêng |
|---|---|---|
| Cây lớn | 320–360 × 400–460 | gốc cây ở giữa cạnh dưới, cách đáy 12 texel |
| Bụi / dương xỉ | 150–180 × 110–130 / 120 × 90 | chân ở giữa đáy, cách 6 texel |
| Đá lớn / nhỏ | 220 × 160 / 110 × 80 | đáy phẳng, cách đáy 6–8 texel |
| Cột / cột gãy | 112 × 300 / 112 × 210 | bệ vuông 0.78 tile (thoi 100 × 50 texel), đỉnh dưới của thoi bệ ở giữa đáy, cách 3 texel |
| Vòm | 300 × 330 | 2 trụ vuông 0.62 tile cách nhau 3 tile theo trục i (xuống-phải), vòm nằm trong mặt SW |
| Tường đổ | 220 × 200 | dài 2.4 tile theo trục i, dày 0.4 tile, cao ≤ 52 px |
| Lối đi trên vòm | 398 × 331 | hộp 4.6 × 1.5 tile cao 64 px, vòm ở mặt SW, tâm vòm cách đầu trái 1.25 tile |
| Cầu thang | 216 × 240 | 7 bậc, rộng 1.5 tile, chạy 1.75 tile, leo về phía trên-phải |
| Cầu gỗ | 308 × 178 | ván ngang, dài 3.6 tile theo trục j (xuống-trái), rộng 1.1 tile |
| Texture nền (cỏ, đất, đá lát) | 512 × 512 | **vẽ top-down (nhìn thẳng xuống), KHÔNG vẽ iso**, liền mạch 4 cạnh (seamless/tileable); đá lát: lưới 8 × 8 viên vuông |
| Dải vách đá | 512 × 128 | nhìn thẳng mặt vách, liền mạch theo chiều ngang, sáng ở mép trên, tối dần xuống chân |
| Mép cỏ / chân vách | 512 × 48 | nền trong suốt, liền mạch theo chiều ngang |
| Decal atlas | 256 × 64 (4 ô 64 × 64) | mỗi ô lề trong suốt ≥ 4 texel |
| Phông xa | 1024 × 768 | liền mạch theo chiều ngang; trên: trời + núi + lâu đài mờ; dưới: tan vào màu sương `#99ADB8` |

**Hậu kỳ bắt buộc:** xóa nền hoàn toàn (không viền trắng/halo), thêm lề trong suốt ≥ 4 texel, kiểm tra hướng sáng trên-trái, kiểm tra đỉnh thoi khớp lưới (đặt ảnh lên khuôn placeholder ở 50% opacity), xuất PNG RGBA 8-bit, thay đúng tên file placeholder để scene tự nhận.
