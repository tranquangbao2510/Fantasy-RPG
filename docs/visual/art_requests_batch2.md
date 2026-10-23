# Danh sách gen art — đợt 2: đồ vật gameplay + icon (TASK M7)

Kích thước, anchor, footprint: [environment-style-guide.md](environment-style-guide.md) mục 13 (và `core/object_art/object_art.json`). Quy trình: mục 11.1 — gen bằng ChatGPT trên **nền magenta `#FF00FF`**, xóa nền + dọn viền hồng, đặt lên **khuôn** `tools/object_art/templates/<file>.png` ở 50 % opacity để căn chân vật đúng chữ thập đỏ và đáy đúng thoi xanh, xuất PNG RGBA **đúng kích thước khuôn**, ghi đè file trong thư mục `art/` → mở game kiểm tra ở zoom 1× và 2×.

Không cần vẽ: **bóng đổ** (code vẽ — đừng để bóng trong ảnh), **ngọn lửa trại** (code), **đất ướt** (tint của ảnh đất khô), quái, nhân vật, UI, art môi trường đã có.

## Prompt chung — đồ vật (dán trước mô tả từng món)

> hand-painted 2D fantasy game asset, isometric view, 2:1 dimetric projection, camera looking from the south, ground grid edges at 26.57 degrees, vertical edges perfectly vertical, soft painterly brushwork, rich but harmonious colors, sunlight from the upper left, top faces brightest, left (south-west) faces medium, right (south-east) faces darkest, single object centered, isolated on a flat solid magenta (#FF00FF) background, no cast shadow on the ground, no ground plane, no text, no border

**Phủ định:** `pixel art, perspective distortion, vanishing point, top-down, side view, front view, tilted verticals, multiple light sources, harsh outlines, background scenery, cast shadow, drop shadow, cropped, magenta tint on the object`

## Prompt chung — icon (dán trước mô tả từng item)

> hand-painted fantasy RPG inventory icon, single item, three-quarter view from slightly above, soft painterly brushwork, rich but harmonious colors, sunlight from the upper left, gentle rim light, item fills about 80% of a square canvas, centered, isolated on a flat solid magenta (#FF00FF) background, no frame, no slot border, no background shape, no text, no letters, no numbers

**Phủ định:** `pixel art, icon frame, rounded square, badge, border, text, letters, watermark, photo, 3d render, multiple items, cropped`

Icon xuất **128 × 128** (gen vuông lớn hơn rồi thu nhỏ), lề trong suốt ≥ 4 texel, đặt `features/items/icons/<id>.png`.

## Thứ tự ưu tiên (thấy nhiều nhất khi chơi → gen trước)

| # | Asset | Lý do |
|---|---|---|
| 1 | `soil_tilled`, `crop_wheat_*`, `crop_potato_*`, `crop_berry_bush_*` | Ruộng 6 × 4 ô ngay cạnh nhà, nhìn thấy cả ngày |
| 2 | `chest_closed` / `chest_open`, `workbench`, `bed` | Nhà tạm — quay về mỗi ngày |
| 3 | Icon dùng nhiều: wood, branch, fiber, stone, berry, wheat_seed, wheat, potato, seed_potato, stone_axe, stone_pickaxe, stone_hoe, watering_can, torch, campfire, bread, raw_meat, grilled_meat | Mở túi đồ / chế tạo liên tục |
| 4 | `campfire`, `tree_stump`, `rock_node_depleted`, `berry_bush_full` / `_depleted`, `wild_potato_full` / `_depleted` | Mỗi vòng khai thác / mỗi đêm |
| 5 | `stone_mill`, `tent`, `death_bag` | Dùng vài lần |
| 6 | Icon còn lại (flour, roasted_*, bandage, hide, bone, shadow_essence, bone_spear, leather_armor, essence_torch, lantern, herb, ancient_relic, tent, stone_mill) | Ít gặp hơn |
| 7 | `rock_node_full` | Đang dùng bản sao `rock_small.png` (đã là art thật) — chỉ gen nếu muốn đá khai thác khác đá trang trí |
| 8 | `training_dummy`, `notice_board`, `class_training_station` | Đồ thử nghiệm / debug |

## Đồ vật

Kích thước = kích thước ảnh xuất (texel). "Chân" = chữ thập đỏ trên khuôn.

### 1. Đất đã cày — `features/farming/art/soil_tilled.png` (144 × 80)
- **Mô tả:** `one isometric diamond tile of freshly tilled dry farm soil, light brown earth, two shallow parallel furrows running from upper-left to lower-right, a few clods and tiny pebbles, soft edges blending to transparent, flat on the ground, no plants`
- **Trạng thái:** 1 ảnh (đất khô). Ướt = code nhân tint tối, nên giữ màu đất sáng, ít bóng đậm.
- **Khớp khuôn:** thoi phủ đúng thoi xanh (64 × 32 px world = 128 × 64 texel), tâm thoi ở chữ thập; mép thoi hơi thụt vào (ô cạnh nhau có khe nhỏ).

### 2. Cây trồng — `features/farming/art/crop_<id>_stage_<n>.png` (144 × 120, 4 giai đoạn mỗi cây)
Ảnh phủ **cả một ô ruộng** (4 khóm xếp theo thoi: sau, trái, phải, trước), chân khóm trên mặt thoi, không vẽ đất (đất là ảnh riêng).
- **Lúa mì** `crop_wheat_stage_0..3`: `a 2x2 cluster of wheat plants on one isometric farm tile` + giai đoạn: 0 `tiny green sprouts`, 1 `young green wheat blades`, 2 `tall green-yellow wheat stalks`, 3 `ripe golden wheat with heavy grain heads` (cao tối đa ~20 px world = 40 texel).
- **Khoai** `crop_potato_stage_0..3`: `a 2x2 cluster of potato plants` + 0 `small sprouts`, 1 `leafy green bushes`, 2 `fuller leafy bushes`, 3 `mature yellowing potato plants with a few brown potatoes peeking from the soil` (thấp, ~12 px world).
- **Bụi mọng** `crop_berry_bush_stage_0..3`: `a 2x2 cluster of small berry shrubs` + 0 `seedlings`, 1 `small dark-green shrubs`, 2 `bushy shrubs`, 3 `shrubs covered with bright red berries` (~16 px world).
- **Khớp khuôn:** thoi xanh = ô ruộng; giai đoạn sau cao hơn giai đoạn trước, cùng vị trí khóm. Thêm cây / đổi số giai đoạn trong `features/farming/data/*.tres` → chạy tool để có khuôn mới.

### 3. Rương — `features/inventory/chest/art/chest_closed.png`, `chest_open.png` (88 × 92)
- **Mô tả:** `small sturdy wooden storage chest with dark iron bands and a brass lock, about knee height`; mở: `same chest with the lid swung open backwards, dark empty interior visible`.
- **Trạng thái:** closed / open — **cùng vị trí thân rương**, chỉ khác nắp.
- **Khớp khuôn:** đáy thân trên thoi xanh 30 px rộng; cao ~24 px world (48 texel) khi đóng, nắp mở tới ~30 px.

### 4. Bàn chế tạo — `features/crafting/stations/art/workbench.png` (120 × 96)
- **Mô tả:** `rustic wooden crafting workbench with four legs, a saw and a hammer lying on the top, wood shavings`.
- **Khớp khuôn:** chân bàn trên thoi 40 px; mặt bàn cao ~22 px world.

### 5. Giường — `features/survival/rest/art/bed.png` (120 × 76)
- **Mô tả:** `simple wooden frame bed with a blue wool blanket and a cream pillow, long side running from upper-left to lower-right`.
- **Khớp khuôn:** chân giường trong thoi 40 px; cao ~17 px world; dài tối đa ~52 px world trong khung.

### 6. Lửa trại (đế) — `features/crafting/stations/art/campfire.png` (88 × 64)
- **Mô tả:** `a ring of grey stones around crossed split logs with charred ends and a little ash, NO fire, NO flames, NO smoke`.
- **Khớp khuôn:** vòng đá trên thoi 28 px; thấp (~8 px world). Lửa do code vẽ lên giữa.

### 7. Gốc cây — `features/gathering/nodes/art/tree_stump.png` (80 × 64)
- **Mô tả:** `freshly cut oak tree stump, light wood cut surface with growth rings, rough dark bark, a few roots`.
- **Khớp khuôn:** gốc trên thoi 20 px; cao ~12 px world.

### 8. Đá khai thác — `features/gathering/nodes/art/rock_node_full.png`, `rock_node_depleted.png` (128 × 104)
- **Mô tả:** full `mossy grey boulder with mineable cracks` (tùy chọn — ưu tiên 7); depleted `a few small broken grey rock fragments and gravel on the ground`.
- **Khớp khuôn:** đáy trên thoi 40 px tâm (0, −7); collision + bóng mềm vẫn là của prop `rock_small`.

### 9. Bụi mọng — `features/gathering/nodes/art/berry_bush_full.png`, `berry_bush_depleted.png` (168 × 136)
- **Mô tả:** full `round leafy green bush covered with clusters of bright red berries`; depleted `the same bush without berries`.
- **Trạng thái:** hai ảnh **cùng hình bụi**, chỉ khác quả (ảnh hiện tại: `bush_b.png` ± quả).
- **Khớp khuôn:** đáy trên thoi 51 px tâm (0, −6), cao ~50 px world.

### 10. Khoai dại — `features/gathering/nodes/art/wild_potato_full.png`, `wild_potato_depleted.png` (80 × 76)
- **Mô tả:** full `a small wild potato plant, a few green leaves and a tiny pale flower`; depleted `a small dug hole of loose dark soil`.
- **Khớp khuôn:** thoi 24 px; cây cao ~20 px world.

### 11. Cối đá — `features/crafting/stations/art/stone_mill.png` (88 × 92)
- **Mô tả:** `small hand quern stone mill, two round grey millstones stacked, a hole in the top stone, a wooden handle sticking up`.
- **Khớp khuôn:** đế trên thoi 24 px; cao ~22 px world, cán tới ~27.

### 12. Lều — `features/survival/rest/art/tent.png` (120 × 116)
- **Mô tả:** `small canvas camping tent, khaki fabric, wooden poles, dark open entrance facing the viewer`.
- **Khớp khuôn:** đáy trên thoi 40 px; cao 28–48 px world (khung cho phép tới ~1.2 nhân vật).

### 13. Túi đồ khi chết — `features/survival/death/art/death_bag.png` (72 × 64)
- **Mô tả:** `a brown leather sack tied with a red cord, sitting on the ground`.
- **Khớp khuôn:** đáy trên thoi 20 px; cao ~17 px world.

### 14. Bù nhìn — `entities/enemies/training_dummy/art/training_dummy.png` (96 × 108)
- **Mô tả:** `straw training dummy on a wooden post, burlap body, outstretched straw arms, a red target patch on the chest`.
- **Khớp khuôn:** cọc cắm ở chữ thập; cao ~38 px world (≈ nhân vật). 1 ảnh tĩnh, code làm rung.

### 15. Bảng thông báo — `features/interaction/examples/art/notice_board.png` (104 × 108)
- **Mô tả:** `wooden notice board on two posts with a pinned parchment note`.
- **Khớp khuôn:** hai cọc trên thoi 28 px; cao ~38 px world.

### 16. Trạm huấn luyện class — `features/classes/station/art/class_training_station.png` (104 × 104)
- **Mô tả:** `stone training pillar on a small square base with a purple banner hanging from the top`.
- **Khớp khuôn:** bệ trên thoi 22 px; cao ~34 px world.

## Icon (37 item — mô tả một dòng)

Item `test_*` (test_sword, test_dagger, test_heavy, test_helmet) **không gen** — vẫn có file placeholder.

| # | id | Mô tả (sau prompt chung icon) |
|---|---|---|
| 1 | wood | a small bundle of split firewood logs tied with twine |
| 2 | branch | a single bare wooden branch with a forked tip |
| 3 | fiber | a coiled bundle of green plant fiber |
| 4 | stone | a rough grey stone chunk |
| 5 | berry | a small cluster of shiny red berries with a leaf |
| 6 | wheat_seed | a small cloth pouch spilling golden wheat seeds |
| 7 | wheat | a sheaf of ripe golden wheat tied in the middle |
| 8 | potato | two brown potatoes |
| 9 | seed_potato | a sprouting seed potato with small purple shoots |
| 10 | stone_axe | a stone axe head lashed to a wooden handle |
| 11 | stone_pickaxe | a stone pickaxe with a wooden handle |
| 12 | stone_hoe | a stone hoe blade lashed to a long wooden handle |
| 13 | watering_can | a small wooden watering can with metal bands |
| 14 | torch | a wooden torch with an oil-soaked cloth wrap, unlit |
| 15 | campfire | a bundle of logs and a few stones for a campfire kit |
| 16 | bread | a round loaf of crusty brown bread |
| 17 | raw_meat | a raw red meat chunk with a bone |
| 18 | grilled_meat | a grilled meat chunk on a bone, golden brown |
| 19 | flour | a small sack of white flour |
| 20 | roasted_potato | a roasted potato split open, steaming |
| 21 | roasted_berry | a skewer of roasted dark red berries |
| 22 | bandage | a rolled linen bandage |
| 23 | hide | a folded brown animal hide |
| 24 | bone | a single white animal bone |
| 25 | shadow_essence | a dark purple wisp of shadow inside a small glass vial |
| 26 | bone_spear | a spear with a sharpened bone tip and a wooden shaft |
| 27 | leather_armor | a brown leather vest armor |
| 28 | essence_torch | a torch whose cloth wrap glows faint purple |
| 29 | lantern | a small iron lantern with a warm glass window, unlit |
| 30 | herb | a sprig of green medicinal herbs |
| 31 | ancient_relic | a weathered ancient stone tablet fragment with carved runes |
| 32 | tent | a folded canvas tent bundle with poles |
| 33 | stone_mill | a small quern stone mill |
| — | test_sword, test_dagger, test_heavy, test_helmet | không gen (đồ thử) |

## Nhật ký gen

Ghi mỗi asset sau khi xong để đo thời gian làm art.

| Asset | Số lần gen | Thời gian | Ghi chú |
|---|---|---|---|
| | | | |
| | | | |
| | | | |
| | | | |
| | | | |
