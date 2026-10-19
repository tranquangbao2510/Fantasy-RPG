# Environment Style Guide (TASK VISUAL-01 → VISUAL-02 isometric, nhân vật: CHAR-01)

Tài liệu cho đồ họa môi trường. Mục **[provisional]** là thông số chưa được xác nhận bằng asset thật.

> Trạng thái (VISUAL-02.2): phần lớn art trong `world/environment/art/` đã là **art vẽ tay** (gen AI + hậu kỳ thủ công, quy trình ở mục 11.1). Còn lại **sinh bằng code** (`tools/placeholder_art/`): bóng/đốm sáng mềm, FX (sương, tia nắng, bụi sáng, glow, noise nước) và tile lưới logic — danh sách ở mục 11.2. Kích thước mọi file vẫn đúng như placeholder ban đầu.
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
| Di chuyển | WASD theo hướng màn hình; vận tốc dọc × **0.7** (`IsoActorAdapter.vertical_speed_scale` → `Player`/`Enemy.vertical_speed_scale`). 0.5 là tốc độ đều tuyệt đối trên mặt đất, nhưng đi dọc cảm giác chậm; 0.7 chọn qua thử nghiệm bằng slider (VISUAL-02.2) |

Mọi object có **origin tại điểm chạm đất** (sorting anchor), xem mục 5.

## 3. Tỉ lệ

| Thông số | Giá trị |
|---|---|
| Tile logic | Thoi **64 × 32 px** world (cạnh thoi ≈ 35.8 px) |
| Mật độ texel **[provisional]** | 2 texel / 1 px world → sprite `scale = 0.5`; zoom 2× hiển thị 1:1 **so với viewport gốc 1152×648**. Cửa sổ mặc định 1920×1080 (stretch `canvas_items`) phóng thêm ×1.67 → ở zoom 2× art bị phóng ~1.67 lần (hơi mềm); muốn sắc nét 1:1 ở 1080p cần art ~3.3 texel/px (chưa quyết định) |
| Chiều cao 1 tầng | **64 px** màn hình (= 2 lần chiều cao một ô thoi) |
| Vách vực quanh map | 192 px (3 tầng), tan vào sương |
| Nhân vật | Player (CHAR-01): sprite cao ~39 px world (idle), footprint ellipse 14 × 7 px; enemy placeholder thân ~28 px. **Sprite nhân vật phải thấp hơn 64 px** (tầng), nếu không thứ tự vẽ với vách bị sai — xem mục 12 |
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
- Painted lighting + `CanvasModulate` ấm nhẹ; 1 `PointLight2D` (đá rune); tia nắng additive alpha ≤ 0.13.
- Giá trị hiện tại (VISUAL-02.2, nắng vàng ấm theo ảnh tham chiếu, không cháy sáng): `SunTint` `(1, 0.96, 0.86)`; tia nắng màu `(1, 0.88, 0.62)`, alpha 0.10–0.13 (dao động xuống ½); đốm nắng trên cỏ `(1, 0.9, 0.66)` alpha 0.2 (additive); sương suối `(1, 0.96, 0.86)` alpha 0.13; sương thung lũng xa `(1, 0.97, 0.92)` alpha 0.5. Sương vực và thác giữ trắng (vực mát, tách lớp xa).
- Không đẩy `SunTint` ấm hơn nữa: nó nhân lên mọi pixel nên làm lệch màu art; muốn thêm nắng thì tăng tia nắng/đốm nắng cục bộ.

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
| Ngoại lệ | `terrain/terrain_logic_tiles.png` (atlas tile debug của lưới logic, ẩn khi chơi): **không** mipmap để ô tile không lem màu nhau |

Khi ghi đè file PNG thủ công, file `.import` cũ được giữ nguyên nên thiết lập không đổi. Kiểm tra lại sau mỗi đợt thay art (VISUAL-02.2: mọi texture còn lại đều đúng bảng trên).

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

### 11.1. Quy trình đã dùng thật (VISUAL-02.2)

Quy trình tạo đợt art vẽ tay đầu tiên (commit `780e684` + `ruin_arch.png`):

1. **Gen bằng ChatGPT** (tạo ảnh), theo prompt/kích thước ở bảng trên, placeholder cùng tên làm khuôn góc/tỉ lệ.
2. **Nền magenta `#FF00FF`** (phẳng, một màu) thay cho nền trong suốt khi gen sprite có alpha.
3. **Xóa nền + dọn viền:** xóa nền magenta, dọn viền ám hồng/halo ở mép, giữ lề trong suốt ≥ 4 texel.
4. **File phải đúng y kích thước placeholder** (cùng chiều rộng × cao, cùng vị trí neo). Sprite được neo bằng `image_offset` tính từ **góc trên-trái** ảnh (`FootprintSortedSprite`, prop scene, cầu, cầu thang) → chỉ cần lệch kích thước hoặc lệch chỗ đặt chân là vật bị trôi khỏi footprint/collision. Cách làm: đặt ảnh gen lên canvas đúng kích thước placeholder, căn chân/đỉnh thoi theo placeholder ở 50% opacity rồi mới xuất.
5. **Chỉnh màu theo tông chung** của cả bộ art, giữ hướng sáng trên-trái.
6. **Texture nền (cỏ, đất, đá lát) vẽ top-down và seamless:** gen nhìn thẳng xuống, liền mạch 4 cạnh (nên kiểm tra bằng cách lát 2×2 trước khi ghi đè).
7. Ghi đè PNG cùng tên → Godot import lại (giữ `.import` cũ) → kiểm tra trong Environment Prototype ở zoom 1× và 2×.

Tinh chỉnh phía engine sau khi thay art (không sửa PNG): đường đất dùng `sand_color`/`sand_mix` trong `terrain_path.gdshader` để sáng và giảm tương phản đốm đậm của `dirt_base.png`, mép mờ rộng (`edge_start` 0.3) + noise 2 tầng (`edge_detail`) cho cỏ lấn; đường rộng 1.7 / 1.4 / 1.5 tile (chính / nhánh / trên plateau).

### 11.2. Trạng thái asset

| Trạng thái | Asset |
|---|---|
| **Art vẽ tay** (AI + hậu kỳ) | `cliff/` (cliff_base, cliff_face, cliff_lip); `ground/` (dirt_base, grass_base, stone_floor); `decals/` dirt_patch, flowers, grass_tufts, leaf_litter, moss_patch, pebbles; `props/` tất cả 15 (bush_a/b, fern, rock_flat/large/small, ruin_arch, ruin_blocks, ruin_pillar, ruin_pillar_broken, ruin_wall, rune_stone, tree_oak_a/b, tree_pine); `scenery/` foreground_leaves, valley_far; `structures/` cliff_stairs, footbridge, stone_bridge |
| **Còn sinh bằng code** (`tools/placeholder_art/`) | `decals/` shadow_soft, light_patch, canopy_shadow (bóng/đốm sáng mềm — gradient, không cần vẽ tay); `fx/` glow, light_shaft, mist, mote, water_noise (hiệu ứng/noise dùng trong shader); `terrain/terrain_logic_tiles.png` (tile debug) |

Chạy lại `generate_environment_art.gd` **sẽ ghi đè art vẽ tay** — chỉ chạy với `ART_ONLY=decals,fx,logic`… cho nhóm còn sinh bằng code, và lưu ý nhóm `decals` gồm cả decal đã vẽ tay (commit trước khi chạy).

## 12. Nhân vật — sprite 8 hướng (TASK CHAR-01)

Hiện chỉ Player có sprite thật; enemy/bù nhìn vẫn là polygon placeholder.

| Thông số | Giá trị |
|---|---|
| Nguồn | Sprite sheet render từ model 3D, file trong `entities/player/art/`: `hero_<animation>.png` + mô tả `hero_sprites.json` |
| Góc camera | Iso 30° (cao độ camera 30° → mặt đất nén sin 30° = **0.5**, khớp map 2:1) |
| Hướng | **8 hướng trên mặt đất**, mỗi hàng sheet một hướng theo thứ tự `S, SW, W, NW, N, NE, E, SE` (S = quay mặt về camera, theo chiều kim đồng hồ trên màn hình); mỗi cột một frame |
| Mật độ texel | `texel_scale = 0.5` (2 texel / 1 px world, như asset môi trường) |
| Cỡ | Nhân vật cao ~78 texel = **~39 px world** (idle), luôn < 64 px (1 tầng). Frame lớn hơn ở đòn đánh/death là do kiếm/tư thế, không phải do nhân vật cao hơn |
| Anchor | `anchor` (px texel trong frame) = **điểm chân** chạm đất; trùng origin Player (Y-sort theo chân) |
| Animation | `idle`, `walk`, `run` (loop); `attack_1/2/3`, `cast`, `hit`, `death` (không loop); `fps` gốc ghi trong JSON |
| Import | Như mục 10: mipmaps bật, `fix_alpha_border` bật, Lossless; node dùng lọc **Linear Mipmap** |

**Quy trình:** model 3D → gắn animation bằng **Mixamo** → **render trong Blender** theo 8 hướng ở góc iso 30° → ghép thành sheet (hàng = hướng, cột = frame) + ghi `hero_sprites.json` (`frame_size`, `frames`, `rows`, `anchor`, `fps`, `loop`, `directions`, `texel_scale`). Sau đó trong project:

1. Chép PNG + JSON vào `entities/player/art/`, chạy `--import` (file `.import` mới: bật `mipmaps/generate`).
2. Chạy `tools/player_sprites/build_player_sprite_frames.gd` → sinh lại `hero_sprite_frames.tres` (không nhập frame bằng tay). Tool kiểm tra kích thước sheet khớp `frame_size × frames × rows`.
3. Chạy `tests/player/test_player_sprite.gd`.

Đổi `anchor`/`frame_size` chỉ cần sinh lại `.tres` — tool đệm mọi frame về một canvas chung để điểm chân trùng nhau, `PlayerSprite` lấy offset từ metadata.

**Giới hạn hiện tại:** kiếm vẽ liền trong sheet, chỉ có ở `attack_1/2/3` (chưa có lớp vũ khí tách riêng → idle/walk/run/cast tay không; đổi vũ khí không đổi hình); vạch vũ khí/vùng vung đòn placeholder vẫn vẽ chồng lên để đọc hitbox.
