# Kiến trúc

Tài liệu này phân biệt rõ:

- **[Đã quyết định]**: nguyên tắc bắt buộc áp dụng.
- **[Đã triển khai]**: đang có trong repository.
- **[Chưa triển khai]**: định hướng tương lai, chưa có mã nguồn. Không tạo trước khi có task yêu cầu.

## 1. Tổng quan — Hybrid / Feature-based [Đã quyết định]

Mã nguồn được tổ chức theo **tính năng** (feature) thay vì theo loại file. Scene, script, resource và asset riêng của một tính năng nằm cùng thư mục với tính năng đó. Chỉ những thứ thực sự dùng chung mới nằm ở các thư mục cấp cao như `core/`, `assets/`, `data/`.

"Hybrid" nghĩa là kết hợp: tính năng gameplay nằm trong `features/`, còn các nhóm có vai trò rõ ràng (entity, world, UI, save) có thư mục riêng ở cấp gốc.

## 2. Thư mục

| Thư mục | Vai trò | Trạng thái |
|---|---|---|
| `app/` | Main scene, khởi động và vòng đời ứng dụng | Đã triển khai (`main.tscn`, `main.gd` — màn hình tạm) |
| `docs/` | Tài liệu kỹ thuật | Đã triển khai |
| `core/` | Thành phần kỹ thuật dùng chung, không phụ thuộc gameplay cụ thể | Chưa triển khai |
| `features/` | Module gameplay (mỗi tính năng một thư mục con, vd. `features/combat/`) | Đã triển khai (`interaction/`, `combat/`, `character/`, `skills/`, `classes/`, `items/`, `inventory/` — 2l; `time/`, `survival/` — 2m; `gathering/`, `crafting/` — 2n) |
| `entities/` | Player, NPC, enemy (scene ghép từ component) | Đã triển khai (`player/`, `enemies/` — placeholder) |
| `world/` | Bản đồ, môi trường, camera | Đã triển khai (`world.tscn`, `world.gd`, `maps/test_map/`, `camera/`, `sandbox/`, `environment/` (gồm `iso/`), `environment_prototype/` — 2k, isometric) |
| `ui/` | Thành phần giao diện | Đã triển khai (`interaction/`, `combat/`, `skills/`, `progression/`, `debug/`, `common/`, `inventory/` — 2l; `survival/` — 2m; `crafting/` — 2n) |
| `data/` | Dữ liệu game dùng chung (`.tres` Resource) | Chưa triển khai |
| `assets/` | Tài nguyên dùng chung (sprite, âm thanh, font) | Chưa triển khai |
| `save/` | Logic lưu / tải game | Đã triển khai (`save_service.gd` — Autoload SaveService, 2l) |
| `tests/` | Kiểm thử headless (SceneTree script) | Đã triển khai (`environment/`, 2k; `player/`, 2c; `inventory/`, `save/`, 2l; `survival/`, `smoke/`, 2m; `gathering/`, `crafting/`, 2n; `test_base.gd` + `run_all.gd`) |
| `addons/` | Plugin bên thứ ba (chỉ khi thật sự cần) | Chưa triển khai |
| `tools/` | Công cụ phát triển chạy ngoài game (có `.gdignore`), vd. sinh placeholder art | Đã triển khai (`placeholder_art/`, 2k; `player_sprites/`, 2c; `item_icons/`, 2l) |

Thư mục chỉ được tạo khi có nội dung thực tế. Không tạo thư mục, script hoặc class rỗng để "giữ chỗ".

## 2a. Scene hiện tại [Đã triển khai]

```
app/main.tscn  (Main Scene, entry point)
Main (Control) ── main.gd
├── Background (ColorRect)
└── Center (CenterContainer)
    └── Layout (VBoxContainer)
        ├── StatusLabel (Label)
        ├── EnterButton (Button "Vào game")
        └── SandboxButton (Button "Combat Sandbox (thử nghiệm)") → world/sandbox/combat_sandbox.tscn (2j)
        ├── ContinueButton (Button "Tiếp tục") → SaveService.load_game(1) (2l; mờ nếu chưa có save)
        └── EnvironmentButton (Button "Environment Prototype (Visual 01)") → world/environment_prototype/environment_prototype.tscn (2k)
            └─ nhấn → SceneTree.change_scene_to_file("res://world/world.tscn")

world/world.tscn  (World Scene, mở độc lập được)
World (Node2D) ── world.gd
├── Environment (Node2D)        — nền, trang trí, hiệu ứng môi trường
├── MapContainer (Node2D)       — bản đồ / TileMapLayer
│   └── TestMap (instance world/maps/test_map/test_map.tscn)
├── EntityContainer (Node2D, y_sort_enabled) — player, NPC, enemy
│   ├── Player (instance entities/player/player.tscn, spawn (480, 320))
│   ├── NoticeBoard (400, 256), TestChest (528, 392), TestCrystal (576, 392) — vật thể tương tác thử nghiệm
│   ├── TrainingDummy (656, 240), SimpleEnemy (300, 420) — mục tiêu combat thử nghiệm
│   └── ClassTrainingStation (560, 256) — điểm đổi class thử nghiệm (2i)
├── CameraContainer (Node2D)    — camera
│   └── GameCamera (instance world/camera/game_camera.tscn)
└── UILayer (CanvasLayer)     — UI cố định trên màn hình
    ├── CombatHUD
    ├── SkillBar
    ├── InteractionPrompt
    ├── InteractionFeedback
    ├── ProgressionPanel        — bảng Class/Progression thử nghiệm (2i)
    ├── PickupToast             — "+3 Gỗ" (2l)
    └── InventoryWindow         — túi đồ / rương (2l)
```

- **Main Scene** là entry point: màn hình khởi động tạm và chuyển vào World. Không giữ trạng thái game.
- **World Scene** là gốc của môi trường game. Không phụ thuộc Main Scene, mở và chạy độc lập bằng F6.
- `world.gd` cung cấp public API trả về các container (`get_map_container()`, `get_entity_container()`, ...) và `get_map_rect()`; nối camera với target/map và InteractionDetector với UI lúc `_ready` (qua các export trong `world.tscn`). Không chứa logic gameplay.
- Từ M1 (2l): `map_id` (khóa trong MapCatalog, rỗng = không lưu được), nối túi đồ/rương/vật phẩm trên đất với UI (`inventory_window`, `pickup_layer`, `pickup_toast` — tùy chọn), `drop_item(stack)`, F5/F9 lưu/tải nhanh, khóa combat khi có bảng UI mở. world.tscn: `map_id = test_map`, `EntityContainer/Items` (ItemPickupLayer).
- Chuyển scene dùng trực tiếp `change_scene_to_file()`; chưa có SceneManager, loading screen hay hiệu ứng chuyển cảnh.

Nguyên tắc đặt node vào World:

- Bản đồ → `MapContainer`; entity → `EntityContainer`; camera → `CameraContainer`; phần môi trường không thuộc bản đồ (nền, thời tiết, ánh sáng) → `Environment`.
- Không đặt node gameplay trực tiếp dưới `World`.
- Vật thể **đứng** cần Y-sort cùng entity (rương, bảng, ...) cũng đặt trong `EntityContainer`, origin tại chân.
- UI cố định trên màn hình đặt trong `UILayer` (CanvasLayer), không bị camera zoom/di chuyển.

Chưa triển khai: NPC, enemy chính thức. Combat Sandbox (scene thử nghiệm thứ hai, dùng chung world.gd): xem 2j.

## 2b. Bản đồ thử nghiệm — TestMap [Đã triển khai, placeholder]

```
world/maps/test_map/
├── test_map.tscn               — TestMap (Node2D, texture_filter = Nearest)
│   ├── GroundLayer (TileMapLayer)   — cỏ, đường đất, nền đá; không collision
│   ├── DetailLayer (TileMapLayer)   — hoa, sỏi (trang trí phẳng); không collision
│   ├── ObstacleLayer (TileMapLayer) — đá, bụi cây; có collision
│   └── MapBounds (StaticBody2D, world/maps/map_bounds.gd) — ranh giới bản đồ
├── tileset/test_tileset.tres   — TileSet dùng lại được (resource riêng)
└── assets/test_tiles.png       — atlas placeholder 128×64 (4×2 ô)
```

- **Tile size:** 32×32 (thử nghiệm, chưa phải quyết định chính thức). Map 30×20 ô = 960×640 px, đặt tại gốc tọa độ.
- **Atlas (source 0):** hàng 0 — `(0,0)` cỏ, `(1,0)` cỏ biến thể, `(2,0)` đất, `(3,0)` đá lát; hàng 1 — `(0,1)` hoa, `(1,1)` sỏi, `(2,1)` đá cản, `(3,1)` bụi cây cản.
- **Lọc texture:** đặt `texture_filter = Nearest` trên node `TestMap` (không đổi cấu hình toàn project). Thiết lập pixel-art toàn cục sẽ quyết định cùng độ phân giải chính thức.
- Dữ liệu tile lưu trực tiếp trong `test_map.tscn`; không có script sinh map lúc chạy.
- Đồ họa, bố cục và kích thước map đều là placeholder.

**Chỉnh sửa trong Editor:** mở `world/maps/test_map/test_map.tscn` → chọn một TileMapLayer → tab **TileMap** ở dock dưới → chọn tile và vẽ. Sửa collision/tile: mở `test_tileset.tres` → tab **TileSet** → **Paint** → Physics Layer 0.

### Collision

| Physics layer | Tên | Dùng cho |
|---|---|---|
| 1 | `world` | Vật cản tĩnh của bản đồ (tile ObstacleLayer, MapBounds) |
| 2 | `player` | Player |
| 3 | `interaction` | Vùng Area2D của Interactable (InteractionDetector dò layer này) |
| 4 | `enemy` | Thân CharacterBody2D của enemy (chưa layer nào dò) |
| 5 | `player_hurtbox` | Hurtbox của Player (Hitbox của enemy dò layer này) |
| 6 | `enemy_hurtbox` | Hurtbox của enemy/dummy (Hitbox của Player dò layer này) |
| 7 | `terrain_tier_0` | Tường địa hình / nước / object của tầng 0 (map có ElevationMap, xem 2k) |
| 8 | `terrain_tier_1` | Tường địa hình / object của tầng 1 |

- TileSet physics layer 0: `collision_layer = 1`, `collision_mask = 0` (vật cản tĩnh không cần dò).
- Chỉ tile đá `(2,1)` và bụi `(3,1)` có polygon (24×24, lệch xuống dưới theo chân vật). Ground và Detail tắt `collision_enabled`.
- Player: `collision_layer = 2`, `collision_mask = 1`.
- Interactable: Area2D `layer = 3`, `mask = 0`, `monitoring = false`. InteractionDetector: `layer = 0`, `mask = 3`, `monitorable = false`. Area2D không chặn chuyển động; vật cản của đối tượng là `BlockingBody` (StaticBody2D, layer 1) riêng.

### Ranh giới bản đồ

- `MapBounds` tạo 4 `WorldBoundaryShape2D` (layer `world`) lúc `_ready`, bao quanh `get_used_rect()` của `GroundLayer` × tile size. Kích thước map chỉ lấy từ đây, không hardcode.
- Chọn collision thay vì clamp vị trí: `move_and_slide()` tự tính bán kính collision của player, trượt dọc mép được, và không có nguy cơ clamp đẩy player vào vật cản.
- `get_map_rect()` là public, có thể dùng lại sau (vd. giới hạn camera). Thay thế: xóa node `MapBounds` khi map có tường/vật cản bao thật.

### Thứ tự hiển thị và Y-sort

- Thứ tự vẽ theo thứ tự node: Ground → Detail → Obstacle → (EntityContainer) → ...
- `EntityContainer` bật Y-sort; entity sau này nên đặt origin ở chân (điểm tiếp xúc mặt đất).
- Vật cản hiện tại **thấp**, không Y-sort; entity luôn vẽ đè lên vật cản. Đây là giới hạn được chấp nhận.
- Hướng xử lý vật thể cao (cây, tường) cho task sau: đặt chúng chung một node cha có Y-sort với entity (vd. TileMapLayer có `y_sort_enabled` cùng cấp Y-sort với entity, hoặc scene vật thể riêng trong cùng cây Y-sort). Không dùng Z-index tùy tiện.

## 2c. Player [Đã triển khai, placeholder — hình: sprite 8 hướng (CHAR-01)]

```
entities/player/player.tscn
Player (CharacterBody2D, motion_mode = Floating) ── player.gd
├── Visual (Node2D)
│   ├── Shadow (Polygon2D)        — bóng ellipse tại chân
│   └── Sprite (AnimatedSprite2D) — player_sprite.gd (PlayerSprite): sprite 8 hướng, chân = origin (CHAR-01)
├── CollisionShape2D              — CircleShape2D r=6, tâm (0,-6): chạm tới chân
└── InteractionDetector, HealthComponent, Hurtbox, HitFlash, WeaponEquipment, BasicAttackController, DebugWeaponSwitcher, SkillLoadout, SkillCastingController, PassiveController, ClassManager, CharacterLevel — xem 2e–2i;
    Inventory (24 ô), EquipmentSlots (weapon, head, offhand) — xem 2l; ManaComponent, StaminaComponent, HungerComponent,
    BuffComponent, ItemUser, VisionLight — xem 2m. Player trong group `saveable` (save id `player`, global)
```

- **Origin = chân nhân vật**, nên Y-sort trong `EntityContainer` dựa trên điểm tiếp xúc mặt đất. Visual vẽ phía trên origin. Không dùng Z-index.
- **Input Map** (`project.godot`): `move_up` W/↑, `move_down` S/↓, `move_left` A/←, `move_right` D/→. Dùng physical keycode (đúng vị trí WASD trên mọi layout bàn phím). Script chỉ đọc action, không kiểm tra phím vật lý.
- **Di chuyển:** `_physics_process` → `Input.get_vector()` → `velocity = direction * move_speed` → `move_and_slide()`. `vertical_speed_scale` (mặc định 1) nhân vào thành phần dọc — map isometric đặt 0.7 qua `IsoActorAdapter` (2k). Liên tục, 8 hướng, chéo được chuẩn hóa (|v| ≤ `move_speed`), thả phím thì dừng ngay; không tăng tốc/quán tính.
- `move_speed` (`@export`, mặc định **160 px/s**) — giá trị thử nghiệm. Chạy (Shift ×1.5), né (Space), chỉ số sinh tồn: xem 2m.
- **Spawn:** đặt trực tiếp trong `world.tscn` tại (480, 320), giữa quảng trường đá. Chưa có SpawnManager/checkpoint.
- Placeholder: kích thước collision, tốc độ, vị trí spawn. Visual (sprite) là art production — xem mục "Player visual" dưới đây.
- `player.gd` chỉ đọc input (`basic_attack` → `BasicAttackController.request_attack()`), chặn điều khiển khi chết và cung cấp `is_dead()`, `reset_state()`, `get_aim_direction(world_point)`, `set_combat_input_blocked(bool)` (UI đang mở: bỏ qua đánh thường/kỹ năng, hủy ngắm/vận sức/combo; di chuyển vẫn được). Tốc độ = `move_speed` × hệ số passive. Logic HP/đòn đánh/class nằm trong component.

**Player visual [CHAR-01]** — `entities/player/player_sprite.gd` (`PlayerSprite`, AnimatedSprite2D trong `Visual`, cạnh bóng `Shadow`). Chỉ hiển thị, không đổi logic/chỉ số combat.

- **Dữ liệu:** `entities/player/art/hero_*.png` + `hero_sprites.json` (render từ model 3D, quy trình: style guide mục 12). `tools/player_sprites/build_player_sprite_frames.gd` sinh `hero_sprite_frames.tres`: animation `<tên>_<hướng>` (9 × 8 = 72, fps/loop gốc), frame là AtlasTexture đệm `margin` về một canvas chung 176 × 164 texel để mọi frame cùng điểm chân; metadata `anchor` (88, 133), `texel_scale` 0.5, `directions`. `PlayerSprite._ready()` đặt `offset = −anchor`, `scale = texel_scale`, lọc Linear Mipmap → điểm chân trùng origin Player.
- **Hướng:** `player.gd._set_facing()` gọi `PlayerSprite.set_facing(dir)`. Hướng màn hình → mặt đất (`GroundSpace.to_ground`, `squash` nhận qua `set_ground_squash()` — `IsoActorAdapter` gọi 0.5; map cũ giữ 1) → làm tròn về 1 trong 8 hàng (`direction_index()`). Đi: theo hướng phím; đánh: theo hướng đòn (con trỏ, chốt mỗi bước); cast: theo mục tiêu. attack/cast/death khóa hướng tới khi xong.
- **Trạng thái → animation** (ưu tiên death > attack / cast (cái sau thắng) > hit > locomotion), cập nhật mỗi physics tick (chạy sau `Player._physics_process`):

| Trạng thái | Animation | Thời lượng |
|---|---|---|
| Đứng yên / đi | `idle` / `run` (tốc độ trên mặt đất ≥ `run_speed_threshold` 110 px/s) / `walk` (thấp hơn, vd. passive làm chậm, trượt dọc tường) | fps gốc |
| Bước combo i (`BasicAttackController.step_started`) | `attack_1/2/3` (vũ khí > 3 bước quay vòng: Dagger bước 4 → `attack_1`) | tua = windup + active + recovery của bước (`get_step(i)`), kết thúc khi controller hết `is_attacking()` |
| Kỹ năng `cast_started(slot, cast_time)` | `cast` | tua = max(cast_time, `min_cast_duration` 0.35 s); `cast_cancelled` → dừng |
| `HealthComponent.damaged` (không đang đánh/cast) | `hit` | tua về `hit_duration` 0.3 s; chỉ hiển thị, không chặn input |
| `died` | `death` | tua về `death_duration` 1.5 s, giữ frame cuối; `revived` (reset R) → idle |

- `HitFlash` vẫn đổi `modulate` của `Visual` (nháy đỏ, tô xám khi chết). `WeaponVisual`/`SwingVisual` của BasicAttackController (vạch vũ khí, vùng vung đòn placeholder) vẫn vẽ.
- `BasicAttackController.get_step(index)` (mới, chỉ đọc) để visual đọc nhịp bước.
- **Kiểm thử:** `tests/player/test_player_sprite.gd` — 53 ca: SpriteFrames đủ 72 animation khớp JSON, anchor chung, sheet có mipmaps, nhân vật cao 39 px world; 8 vector mặt đất → đúng hàng (iso + map cũ), làm tròn; idle/run/walk theo phím; attack_1/2/3 tua khớp từng bước của Sword/Dagger/Heavy và tới frame cuối đúng lúc hết recovery; cast tua theo cast time, hủy cast; hit không chặn di chuyển, không ngắt đòn; death giữ frame cuối, reset về idle_S; map cũ squash 1.
- **Giới hạn:** kiếm chỉ có trong `attack_1/2/3` (vẽ liền trong sheet, chưa có lớp vũ khí tách riêng; đổi vũ khí không đổi hình); `run`/`walk` phát ở fps gốc, không khớp sải chân với tốc độ thật; Player chỉ có một tốc độ nên bình thường luôn `run`; enemy/bù nhìn vẫn là polygon.

## 2d. Camera — GameCamera [Đã triển khai]

```
world/camera/game_camera.tscn
GameCamera (Camera2D, class_name GameCamera) ── game_camera.gd
  process_callback = Physics, position_smoothing_enabled = true, speed = 8
```

- **Target:** `set_target(node: Node2D)`. Camera nhảy ngay tới target và gọi `reset_smoothing()` (không trượt từ (0,0)). Target null/đã free: cảnh báo một lần, camera đứng yên, không crash. Camera không biết Player; không xoay (`ignore_rotation` mặc định).
- **Map:** `set_map_rect(rect: Rect2)` (world coordinates) đặt `limit_*` của Camera2D và tính lại zoom.
- **Nối trong World:** `world.tscn` gán 3 export của `world.gd`: `camera`, `camera_target` (Player), `map_bounds` (`TestMap/MapBounds`). `World._ready()` gọi `camera.set_map_rect(get_map_rect())` rồi `camera.set_target(camera_target)`. Camera ↔ Player không phụ thuộc nhau.
- **Dùng cho map khác:** instance `game_camera.tscn`, gọi `set_map_rect()` với vùng map mới và `set_target()` với node cần theo. Đổi map lúc chạy: gọi lại `set_map_rect()`.
- **Smoothing:** dùng thuộc tính có sẵn `position_smoothing_enabled` / `position_smoothing_speed` (chỉnh trong Inspector). Vị trí theo dõi được kẹp vào vùng hợp lệ *trước* khi smoothing, nên camera dừng êm ở mép và không bị trễ khi quay lại.
- **Zoom:** theo bội số `zoom_step` (mặc định 1 = mức nguyên như trước; Environment Prototype dùng 0.25, 1×–3×, không ép integer scaling — TASK VISUAL 01). `@export default_zoom = 2`, `min_zoom = 1`, `max_zoom = 4`. Input Map: `camera_zoom_in` = lăn chuột lên, `camera_zoom_out` = lăn chuột xuống; mỗi nấc ±`zoom_step`, đổi tức thì (không tween).
- **Zoom tối thiểu hợp lệ** = `ceil(max(viewport.w / map.w, viewport.h / map.h))`, tính lại khi viewport đổi kích thước. Với viewport mặc định 1152×648 và map 960×640, 1× không hợp lệ → thấp nhất là **2×**. Nếu mức tối thiểu > `max_zoom` (cửa sổ rất rộng), camera dùng mức tối thiểu đó (vượt 4×) và cảnh báo một lần, thay vì để lộ vùng ngoài map.

Hạn chế pixel-art hiện tại:

- Stretch `canvas_items` + `expand` (từ TASK 01) giữ nguyên; viewport gốc 1152×648, **cửa sổ mặc định 1920×1080** (`window/size/window_*_override`, VISUAL-02.2 — Godot tự thu nhỏ nếu màn hình không đủ chỗ). Khi cửa sổ khác 1152×648 theo tỉ lệ không nguyên (vd. 1920×1080 = 1.67×), một pixel nghệ thuật không còn là số nguyên pixel màn hình → kích thước pixel có thể không đều. Sẽ xử lý khi chốt độ phân giải thiết kế.
- Vị trí camera khi smoothing là số thực; chưa bật pixel snap toàn cục (`snap_2d_transforms_to_pixel`) vì có thể gây rung player so với camera. Ưu tiên chuyển động mượt.

## 2e. Interaction System [Đã triển khai]

```
features/interaction/
├── interactable.gd               — class_name Interactable (extends Area2D): base class mỏng
├── interaction_detector.gd/.tscn — class_name InteractionDetector (Area2D): component gắn vào Player
└── examples/                     — đối tượng thử nghiệm (placeholder, không phải nội dung chính thức)
    ├── notice_board.gd/.tscn     — trả về đoạn thông báo (export `message`)
    ├── test_chest.gd/.tscn       — đóng → mở một lần; tương tác lại báo "đã mở"
    └── test_crystal.gd/.tscn     — đổi qua lại hai màu
ui/interaction/
├── interaction_prompt.gd/.tscn   — "[E] Đọc — Bảng thông báo", ẩn khi không có mục tiêu
└── interaction_feedback.gd/.tscn — thông báo kết quả, tự ẩn sau 2.5 s
```

Luồng: Player → `InteractionDetector` → `Interactable.interact()` → chuỗi kết quả → signal `interacted` → `World` → `InteractionFeedback`.

**Public API của Interactable** (đối tượng không tự đọc input):

| Method | Ý nghĩa |
|---|---|
| `can_interact(actor: Node2D) -> bool` | Mặc định trả `interaction_enabled` |
| `get_interaction_name() -> String` | Tên hiển thị (export `interaction_name`) |
| `get_interaction_prompt() -> String` | Động từ hiển thị (export `interaction_prompt`), có thể override theo trạng thái |
| `get_interaction_position() -> Vector2` | Điểm tương tác = `global_position` (origin tại chân) |
| `interact(actor: Node2D) -> String` | Kiểm tra `can_interact` rồi gọi `_perform_interaction()`; trả thông báo kết quả |

**InteractionDetector:**

- Cập nhật danh sách ứng viên qua `area_entered` / `area_exited`, chỉ nhận `Interactable`. Không quét scene tree. Mỗi physics tick loại bỏ tham chiếu đã free, bỏ qua ứng viên `can_interact() == false`, chọn ứng viên gần nhất.
- Chống nhảy mục tiêu: chỉ đổi khi ứng viên khác gần hơn mục tiêu hiện tại > 1 px (`SWITCH_MARGIN`).
- Phạm vi: `@export detection_radius = 48` + bán kính vùng của Interactable (8) → khoảng **56 px** tính từ chân Player tới điểm tương tác.
- Input: action `interact` = **E** (physical keycode), xử lý trong `_unhandled_input` với `is_action_pressed` (bỏ echo → giữ phím chỉ tương tác 1 lần).
- Signal: `target_changed(target)` (null = không có; phát lại sau mỗi lần tương tác vì prompt có thể đổi) và `interacted(target, message)`.
- API: `get_target()`, `try_interact()`, `set_enabled(bool)` / `is_enabled()` (tắt khi actor bị hạ gục; tắt sẽ xóa mục tiêu).

**UI:** `World._ready()` nối `target_changed` → `InteractionPrompt.show_target()` và `interacted` → `InteractionFeedback.show_message()`. UI chỉ đọc public API của Interactable, không gọi `interact()` và không đọc trạng thái nội bộ. Prompt lấy tên phím từ Input Map.

**Tạo đối tượng tương tác mới:**

1. Scene có gốc là `Area2D` với script `extends Interactable`; đặt `collision_layer = 3` (giá trị 4), `collision_mask = 0`, `monitoring = false`.
2. Thêm `CollisionShape2D` nhỏ (vd. hình tròn r=8) tại origin làm điểm tương tác.
3. Override `_perform_interaction(actor) -> String` (và `get_interaction_prompt()` / `can_interact()` nếu cần).
4. Nếu cần chặn đường: thêm `StaticBody2D` con (layer 1 `world`) riêng, không dùng Area2D để chặn.
5. Instance vào `EntityContainer` (để Y-sort cùng Player).

Giới hạn prototype:

- Không raycast kiểm tra vật cản → có thể tương tác xuyên vật cản mỏng nếu nằm trong phạm vi.
- Kết quả tương tác chỉ là chuỗi thông báo; chưa có kiểu kết quả có cấu trúc.
- Trạng thái rương/tinh thể chỉ tồn tại lúc chạy, không lưu.
- Văn bản thử nghiệm viết trực tiếp trong scene/script, chưa có hệ thống bản địa hóa.

## 2f. Combat prototype [Đã triển khai, placeholder]

```
features/character/health_component.gd — class_name HealthComponent (Node)
features/combat/
├── damage_info.gd        — class_name DamageInfo (RefCounted): amount, source
├── hitbox.gd             — class_name Hitbox (Area2D): vùng gây đòn, bật/tắt theo đòn
├── hurtbox.gd            — class_name Hurtbox (Area2D): vùng nhận đòn → HealthComponent
├── attack_component.gd   — class_name AttackComponent (Node2D): base mỏng cho đòn enemy (WINDUP → ACTIVE → COOLDOWN)
├── melee_attack.gd/.tscn — class_name MeleeAttack (AttackComponent): đòn chữ nhật bằng Hitbox (Player dùng BasicAttackController, xem 2g)
├── ranged_attack.gd/.tscn, projectile.gd/.tscn — đòn tầm xa + đạn tối giản (xem 2j)
├── feedback/hit_spark.gd — class_name HitSpark: hiệu ứng trúng đòn placeholder (chỉ hiển thị)
├── knockback_component.gd — class_name KnockbackComponent (Node): đẩy lùi cho CharacterBody2D
└── hit_flash.gd          — class_name HitFlash (Node): nháy màu / tô xám theo HP (chỉ visual)
entities/enemies/
├── training_dummy/       — Node2D đứng yên, HP 60, không AI
├── enemy.gd, enemy_base.tscn — class_name Enemy (CharacterBody2D): AI dùng chung (xem 2j); scene gốc cho mọi enemy prototype
└── simple_enemy/, stationary_attacker/, ranged_enemy/ — scene kế thừa enemy_base + AttackComponent
ui/combat/
├── combat_hud.gd/.tscn   — HP Player, thông báo bị hạ gục, gợi ý phím
├── damage_numbers.gd     — số sát thương neo vào vị trí world, vẽ trên màn hình
└── world_health_bar.gd   — thanh HP nhỏ trên đầu dummy/enemy
```

**Luồng:** Input (`basic_attack` = chuột trái) → `BasicAttackController` (Player, 2g) hoặc `MeleeAttack` (enemy) → (windup) → `Hitbox.activate(DamageInfo)` → mỗi physics tick duyệt `get_overlapping_areas()` → `Hurtbox.receive_damage(info)` → `HealthComponent.apply_damage()` → signal `damaged` / `health_changed` / `died` → HitFlash, WorldHealthBar, CombatHUD, logic chết của thực thể.

**HealthComponent** — `max_health` (export), `current_health`, `is_dead()`, `apply_damage(n) -> int`, `heal(n) -> int`, `reset()`. HP kẹp trong [0, max]; amount ≤ 0 bị bỏ qua; đã chết thì không nhận damage/heal; `died` phát đúng 1 lần cho tới `reset()` (phát `revived`). Không biết chủ thể là gì.

**Damage** — `DamageInfo.new(amount, source)` + `knockback: Vector2`; một instance dùng chung cho mọi mục tiêu của một đòn. Mục tiêu = Hurtbox nhận đòn. Chưa có chỉ số/phòng thủ/chí mạng/nguyên tố; mở rộng bằng cách thêm field vào DamageInfo.

**Hitbox / Hurtbox**

- Hitbox: `activate(info)` / `deactivate()` (đổi `monitoring` bằng `set_deferred`); chống trúng lặp bằng danh sách khóa mục tiêu trong một lần activate (`Hurtbox.get_damage_key()` = HealthComponent, nên nhiều Hurtbox cùng một HP chỉ tính một lần). Dùng `get_overlapping_areas()` thay vì `area_entered` để mục tiêu đứng sẵn trong vùng lúc bật vẫn bị trúng.
- Hurtbox: `health` (export); bỏ qua đòn có `source == owner` (tự đánh mình), amount không hợp lệ, hoặc mục tiêu đã chết. Phát `hit_received(info, applied)`. Tự vào group `hurtboxes`.
- Phe = collision layer: Player Hurtbox layer 5, enemy/dummy Hurtbox layer 6. Hitbox `layer = 0`; Player Hitbox mask 6, enemy Hitbox mask 5 → không tự đánh, dummy/enemy không đánh lẫn nhau. Hitbox/Hurtbox là Area2D, không chặn chuyển động, không dùng layer `interaction`.

**MeleeAttack** (enemy; export của AttackComponent + `attack_width`, mọi giá trị là placeholder; các enemy khác xem 2j):

| | damage | attack_range | attack_width | windup | duration | cooldown | target_layers |
|---|---|---|---|---|---|---|---|
| SimpleEnemy | 10 | 26 | 20 | 0.35 s | 0.15 s | 1.0 s | 5 `player_hurtbox` |

API: `attack(direction) -> bool`, `can_attack()`, `is_attacking()`, `cancel()`, `get_hitbox()`; signal `attack_started(direction)`, `attack_finished`. Chỉ xoay node MeleeAttack (Hitbox + visual), không xoay thực thể. Đang đánh/nghỉ thì bỏ qua. Không đánh khi `health` của chủ thể đã chết.

**SimpleEnemy** (= Melee Chaser, `Enemy` với `movement_mode = CHASE`) — export `target` (World gán Player), `move_speed` 70, `detection_range` 150, `attack_trigger_ratio` 0.8 × `attack.attack_range`. Ngoài tầm: đứng yên; trong tầm: đi thẳng tới target (`move_and_slide`, mask `world`, có thể kẹt sau vật cản, không pathfinding); đủ gần: đứng lại và đánh. Chỉ đọc vị trí và `is_dead()` của target (nếu có), không đọc HP. Chết: dừng AI, hủy đòn. Thân enemy layer 4, mask 1; Player và enemy không chặn nhau.

**Chết / reset (thử nghiệm):**

- Player chết: không di chuyển/tấn công, `InteractionDetector.set_enabled(false)`, tô xám, HUD hiện "Bạn đã bị hạ gục".
- Phím **R** (`debug_reset`, không phải phím chính thức): `World.reset_test_state()` gọi `reset_state()` trên mọi node group `test_resettable` (Player, dummy, enemy) rồi `camera.set_target()` để camera nhảy ngay về Player. Player về spawn, HP đầy, vận tốc 0, hủy đòn; enemy về spawn. Không reload scene.

**HUD / feedback:** `World._ready()` gọi `CombatHUD.bind_player_health()` và nối `hit_received` của mọi Hurtbox trong World tới `CombatHUD.show_damage()` (số sát thương + "Hạ gục!"). DamageNumbers chuyển vị trí world → màn hình bằng `get_canvas_transform()` mỗi frame nên đúng ở mọi mức zoom. UI không tính damage, không sửa HP.

**Thêm một mục tiêu có HP:** thêm `HealthComponent` + `Hurtbox` (Area2D, `layer` = 5 hoặc 6 theo phe, `mask = 0`, `monitoring = false`, gán `health`, thêm CollisionShape2D); tùy chọn `HitFlash`, `WorldHealthBar`. Muốn tấn công: instance `melee_attack.tscn`, đặt `target_layers` = layer Hurtbox phe đối địch, gán `health`. Muốn reset bằng R: thêm vào group `test_resettable` và viết `reset_state()`. Đặt trong `EntityContainer`.

**Kiểm tra trong game:** F5 → Vào game. Chuột trái để chém về phía con trỏ; dummy (bù nhìn rơm, bên phải quảng trường) và enemy đỏ (dưới trái) có thanh HP. Đến gần enemy để nó đuổi và đánh. **R** để reset.

Giới hạn prototype:

- Hurtbox được nối vào HUD lúc `World._ready()`; thực thể sinh ra lúc chạy gọi `World.register_entity(node)` (không nối trùng).
- Không i-frame: enemy đánh trúng mỗi lần hết cooldown. Knockback chỉ có ở SimpleEnemy (Player và dummy không bị đẩy).
- Enemy không pathfinding, không tránh vật cản; Player và enemy có thể chồng lên nhau.
- Vùng tấn công là hình chữ nhật; Player có animation sprite (2c, CHAR-01), enemy chưa.
- `get_global_mouse_position()` đọc con trỏ thật nên kiểm thử tự động không giả lập được hướng chuột (đã tách `get_aim_direction()` để kiểm thử).

## 2g. Weapon & basic attack combo [Đã triển khai, placeholder]

Quy tắc đã chốt: một class dùng được nhiều loại vũ khí; **mỗi loại vũ khí có combo đánh thường riêng**; **kỹ năng chủ động thuộc class, không thuộc vũ khí**; ultimate là một trong bốn ô active skill. Module này chỉ lo vũ khí + đánh thường; chưa có class/skill/ultimate.

```
features/combat/weapons/
├── weapon_definition.gd        — class_name WeaponDefinition (Resource)
├── combo_definition.gd         — class_name ComboDefinition (Resource)
├── combo_step_definition.gd    — class_name ComboStepDefinition (Resource)
├── weapon_equipment.gd         — class_name WeaponEquipment (Node): vũ khí đang trang bị
├── basic_attack_controller.gd/.tscn — class_name BasicAttackController (Node2D): chạy combo
├── debug_weapon_switcher.gd    — class_name DebugWeaponSwitcher (Node): phím debug 1/2/3
└── data/                       — test_sword/dagger/heavy.tres + combo_test_*.tres
```

**Schema (definition = dữ liệu thiết kế, chỉ đọc lúc chạy):**

| Resource | Field |
|---|---|
| `WeaponDefinition` | `weapon_id: StringName` (ổn định, không phụ thuộc tên), `display_name`, `weapon_type_id: StringName`, `combo: ComboDefinition`, nhóm *Placeholder visual*: `visual_color`, `visual_length`, `visual_width`. `is_valid()` |
| `ComboDefinition` | `steps: Array[ComboStepDefinition]`, `input_buffer` (giây). `get_step_count()`, `get_step(i)`, `is_valid()` |
| `ComboStepDefinition` | `damage`, `attack_range`, `attack_width` (hitbox chữ nhật riêng từng bước), `windup`, `active`, `recovery`, `link_window`, `knockback` (px/s), `effect_color`. `is_valid()` |

Runtime state (bước hiện tại, phase, thời gian, buffer, hướng, shape Hitbox) nằm trong `BasicAttackController` / `WeaponEquipment` của từng thực thể; không ghi vào Resource.

**WeaponEquipment** — export `starting_weapon`; `get_weapon()`, `equip_weapon(w) -> bool` (bị từ chối → giữ vũ khí cũ, phát `equip_rejected(weapon, reason)`; definition lỗi còn cảnh báo), `unequip_weapon()`, `can_equip(w)`, `get_equip_block_reason(w)`, `set_equip_validator(callable)` (ClassManager gắn luật class ↔ `weapon_type_id`, xem 2i); signal `weapon_changed(weapon)`. Không tính damage.

**BasicAttackController** — export `equipment`, `health`, `target_layers`. Lấy combo từ vũ khí đang trang bị; đổi vũ khí → `cancel()` rồi dùng combo mới.

- Phase: `READY → WINDUP → ACTIVE (Hitbox bật) → RECOVERY → LINK → READY`.
- Nhấn khi READY → bước 1; trong LINK → bước kế; hết LINK hoặc xong bước cuối → về bước 1 (`combo_ended(completed)`).
- Nhấn khi đang đánh: chỉ ghi nhớ **1 lần** nếu còn ≤ `input_buffer` tới hết recovery, chạy ngay khi recovery kết thúc (không bỏ qua recovery); sớm hơn thì bỏ qua.
- Hướng đánh chốt lúc bắt đầu mỗi bước (`set_aim_provider(callable)`, Player cung cấp hướng tới chuột); di chuột trong lúc đòn chạy không xoay hitbox. Chỉ xoay node controller. Player vẫn di chuyển bình thường.
- Mỗi bước là một lần `Hitbox.activate()` mới → mỗi mục tiêu trúng tối đa 1 lần/bước.
- `cancel()` khi chết, reset, đổi vũ khí: tắt Hitbox, xóa buffer, về READY.
- API: `request_attack() -> bool`, `cancel()`, `get_phase()`, `get_step_index()` (−1 khi chưa đánh), `get_step_count()`, `is_attacking()`, `has_buffered_input()`, `get_hitbox()`; signal `step_started(index, count, direction)`, `phase_changed(phase, index, count)`, `combo_ended(completed)`, `hit_landed(hurtbox, applied)`.

**Luồng:** chuột trái → `player.gd` → `request_attack()` → bước combo (dữ liệu từ WeaponDefinition) → `Hitbox.activate(DamageInfo{damage, source, knockback})` → Hurtbox → HealthComponent (như 2f).

**Knockback** — `DamageInfo.knockback = hướng đòn × step.knockback`. `KnockbackComponent` (trên SimpleEnemy) nhận qua `Hurtbox.hit_received`, giảm dần (`decay`), thân enemy cộng vào `velocity` trước `move_and_slide()` → vật cản vẫn chặn. Đặt `knockback = 0` (dữ liệu) hoặc `strength_multiplier = 0` để tắt. Đã chết thì không nhận; reset xóa. Không có stagger/stun.

**Feedback** — `WeaponVisual` (Line2D, màu/độ dài/độ dày theo vũ khí) chỉ hướng đòn cuối; `SwingVisual` (Polygon2D đúng kích thước hitbox của bước): mờ khi windup, đậm khi active (màu theo bước), mờ dần khi recovery, chớp trắng khi trúng. HUD: tên vũ khí, dòng debug `Combo 2/3 · ACTIVE`, "Combo: hoàn thành" khi đánh hết chuỗi.

**Vũ khí thử nghiệm** (placeholder, không phải cân bằng chính thức):

| Vũ khí | Bước | Damage | Range × width | Nhịp mỗi bước (windup/active/recovery) | Buffer |
|---|---|---|---|---|---|
| Test Sword | 3 | 12 / 14 / 22 | 32–38 × 22–32 | ~0.06 / 0.10 / 0.14–0.30 s | 0.20 s |
| Test Dagger | 4 | 6 / 6 / 7 / 12 | 22–26 × 16–24 | ~0.03 / 0.07 / 0.08–0.20 s | 0.15 s |
| Test Heavy Weapon | 2 | 30 / 45 | 40–44 × 44–52 | 0.25–0.32 / 0.14–0.16 / 0.40–0.55 s | 0.25 s |

**Phím debug** (không phải phím chính thức): `1` Sword, `2` Dagger, `3` Heavy (`debug_weapon_1..3`, xử lý bởi `DebugWeaponSwitcher`; xóa node này khi có quy trình trang bị chính thức). Từ M1 ô `weapon` của `EquipmentSlots` tự đồng bộ theo (2l).

**Tạo vũ khí mới:** FileSystem → New Resource → `ComboStepDefinition`/`ComboDefinition` (hoặc nhân bản `combo_test_*.tres`) → chỉnh các bước; New Resource → `WeaponDefinition`, đặt `weapon_id`, `weapon_type_id`, gán `combo`. Gán vào `WeaponEquipment.starting_weapon` hoặc thêm vào mảng `DebugWeaponSwitcher.weapons`. Không cần sửa code.

Giới hạn: hitbox mỗi bước là hình chữ nhật (chưa có arc thật); animation Player attack_1/2/3 tua theo nhịp bước (2c), enemy chưa có animation; enemy vẫn dùng MeleeAttack đơn (không combo). Luật class ↔ vũ khí: xem 2i.

## 2h. Active skill framework [Đã triển khai, placeholder]

Quy tắc đã chốt: đúng **4 ô** kỹ năng chủ động (ultimate dùng một trong 4 ô, không có ô thứ 5); mỗi kỹ năng có cast mode **Normal / Quick / Instant** cấu hình riêng; kỹ năng thuộc **class**, không thuộc vũ khí. Class, skill level/evolution, passive: xem 2i. Chưa có ultimate, mana/stamina/cost.

```
features/skills/
├── skill_definition.gd          — class_name SkillDefinition (Resource) + enum TargetingType/CastMode/EffectType
├── skill_runtime.gd             — class_name SkillRuntime (RefCounted): charges, hồi charge, recast delay, cast mode
├── skill_loadout.gd             — class_name SkillLoadout (Node): 4 ô
├── skill_target.gd              — class_name SkillTarget (RefCounted): origin/direction/point đã giải quyết
├── skill_casting_controller.gd/.tscn — class_name SkillCastingController (Node2D): input + state machine
├── skill_area_visual.gd         — class_name SkillAreaVisual (Node2D): vẽ indicator / flash (chỉ visual)
├── skill_effect_executor.gd     — class_name SkillEffectExecutor (RefCounted, static): DAMAGE / HEAL
└── data/                        — test_arc_slash, test_ground_burst, test_linear_strike, test_self_heal (.tres)
ui/skills/  skill_bar.gd/.tscn, skill_slot_view.gd/.tscn      ui/common/input_hint.gd — tên phím từ Input Map
```

**SkillDefinition** (dữ liệu thiết kế, không chứa runtime state, không có field vũ khí): `skill_id` (ổn định), `display_name`, `short_name`, `description`, `default_cast_mode`; *Targeting*: `targeting_type` (SELF / LINE / GROUND_CIRCLE / CONE), `cast_range`, `radius`, `width`, `angle_degrees`; *Timing*: `cast_time`, `cooldown`, `max_charges`, `recast_delay`; *Effect*: `effect_type` (DAMAGE / HEAL), `effect_amount`, `knockback`; *Indicator*: `indicator_color`. `is_valid()` kiểm tra theo loại targeting.

**Mana (TASK M2):** `SkillDefinition.mana_cost`, trừ lúc bắt đầu vận sức cùng charge; thiếu → `cast_rejected("Thiếu mana")` — xem 2m.

**Cooldown & charges (quy tắc prototype):** mỗi lần thi triển tiêu 1 charge; khi charges < max, hồi **lần lượt từng charge** sau mỗi `cooldown` giây (`max_charges = 1` → cooldown thông thường). `recast_delay` = khoảng nghỉ tối thiểu giữa 2 lần thi triển. Thi triển được khi charges > 0 và hết recast delay. Không có global cooldown.

**SkillRuntime** — một instance cho mỗi ô; `can_cast()`, `consume()`, `tick(delta)`, `reset()`, `get_charges()`, `get_cooldown_remaining()`, `get_recharge_remaining()`, `get_block_reason()`, `cast_mode`, `is_casting`, `set_definition(def)` (thay definition sau khi lên level/tiến hóa, giữ charges/hồi chiêu, kẹp charges theo max mới); signal `changed`. Không ghi vào Resource.

**SkillLoadout** — `SLOT_COUNT = 4`; export `starting_skills`, `starting_cast_modes` (Player để trống: ClassManager xếp loadout); `equip_skill(slot, def) -> bool`, `unequip_skill(slot)`, `update_definition(slot, def)`, `find_slot(skill_id)`, `get_skill(slot)`, `get_runtime(slot)`, `set_cast_mode(slot, mode)`, `cycle_cast_mode(slot)`, `reset_runtimes()`, `can_equip(slot, def)`, `get_equip_block_reason(slot, def)`, `set_equip_validator(callable)` (luật class, xem 2i); signal `slot_changed`, `cast_mode_changed`, `equip_rejected(slot, def, reason)`. Ô ngoài [0, 3] bị từ chối. **Quy tắc prototype: một kỹ năng chỉ ở một ô** (trang bị trùng bị từ chối). Equip mới tạo runtime mới (charges đầy).

**SkillCastingController** — export `loadout`, `health`, `target_layers` (Player: 6 `enemy_hurtbox`). State `IDLE → TARGETING → CASTING → IDLE`:

| Mode | Bắt đầu | Xác nhận | Hủy |
|---|---|---|---|
| Normal | nhấn phím ô → TARGETING | click trái | `skill_cancel`, nhấn lại cùng phím |
| Quick | giữ phím ô → TARGETING | thả **đúng phím đó** | `skill_cancel` khi đang giữ (thả sau đó không cast) |
| Instant | nhấn phím ô → chốt điểm ngắm lúc nhấn | — | — |

- Không vào TARGETING nếu kỹ năng chưa sẵn sàng (phát `cast_rejected(slot, reason)`). Charge chỉ bị tiêu khi bắt đầu CASTING, không tiêu lúc ngắm.
- CASTING: chờ `cast_time` (có thể 0) rồi thực thi effect **đúng 1 lần trong physics tick**. Player vẫn di chuyển khi vận sức; chưa có interrupt-on-hit/stun/silence.
- Đang CASTING: phím ô khác bị từ chối. Đang TARGETING: phím ô khác = hủy ngắm cũ rồi thử ô mới. Đổi/unequip ô hoặc đổi cast mode của ô đang dùng → hủy.
- `skill_cancel` hủy theo mức: đang ngắm → hủy ngắm; đang vận sức → hủy vận sức (**charge đã tiêu không hoàn lại**, prototype). Không có gì để hủy thì event được chuyển tiếp.
- Chết / reset → `cancel_all()`; reset còn gọi `SkillLoadout.reset_runtimes()` (charges đầy, cooldown 0). Chưa bảo toàn cooldown khi hồi sinh.
- API: `handle_input(event) -> bool`, `confirm_targeting()`, `cancel_targeting()`, `cancel_cast()`, `cancel_all()`, `get_state()`, `get_active_slot()`, `is_busy()`, `get_cast_progress()`, `get_current_target()`, `set_aim_provider(callable)`, `fallback_direction`; signal `targeting_started/ended`, `cast_started/finished/cancelled`, `cast_rejected`.

**Targeting** — `SkillTarget.resolve(def, origin, aim_point, fallback)`: origin = controller (Player + (0,−12)); LINE/CONE: hướng tới chuột; GROUND_CIRCLE: điểm chuột **kẹp về `cast_range`** (không từ chối); SELF: tại người thi triển. Indicator (`SkillAreaVisual`, `top_level`, vẽ bằng `_draw` theo world coordinates) dùng cùng `SkillTarget` + definition với effect → vùng hiển thị = vùng tác động; đúng ở mọi mức zoom; không collision, không damage. Khi vận sức có `cast_time`, vùng đã chốt hiện mờ; khi effect xảy ra có flash mờ dần.

**Effect** — `SkillEffectExecutor.execute()` gọi trong physics tick: DAMAGE dùng `PhysicsDirectSpaceState2D.intersect_shape` (chỉ Area2D, `collision_mask = target_layers`; LINE = chữ nhật xoay, GROUND/SELF = tròn, CONE = tròn bán kính `cast_range` rồi lọc góc theo tâm Hurtbox), mỗi mục tiêu 1 lần (khóa `get_damage_key()`), gây sát thương qua `Hurtbox.receive_damage(DamageInfo)` — cùng Damage System, số sát thương/Hạ gục/knockback hoạt động như đánh thường. Player không bị trúng (layer phe + `source == owner`). HEAL: `HealthComponent.heal()` của người thi triển (không vượt max; HUD hiện số "+N").

**Điều phối input** (`player.gd._unhandled_input`): `SkillCastingController.handle_input()` được hỏi trước; nếu đã dùng event → dừng. Click trái chỉ là đánh thường khi controller IDLE (đang ngắm: click thuộc về kỹ năng; đang vận sức: bị chặn). Phím mặc định (prototype, tránh xung đột WASD/E/1/2/3/R): **Q / C / V / X** = ô 1–4, `skill_cancel` = **chuột phải / Esc**. Nút GUI (đổi cast mode) dùng `focus_mode = None` nên không giữ phím.

**Skill HUD** (`SkillBar`, góc dưới phải): 4 ô — phím, tên ngắn, nút cast mode (bấm để xoay Normal → Quick → Instant, chỉ đổi runtime), trạng thái "Sẵn sàng" / thời gian hồi / charges `x/y`, thanh tiến độ vận sức, tô sáng ô đang ngắm, mờ khi chưa thể dùng; dòng thông báo ngắn khi bị từ chối. Chỉ đọc SkillRuntime/controller, không tự tính.

**Kỹ năng prototype** (placeholder, giá trị ở Lv 1; ô trang bị do class quyết định — xem 2i):

| Mode mặc định | Kỹ năng | Targeting | Thông số | Effect | Hồi |
|---|---|---|---|---|---|
| Normal | Test Arc Slash | CONE | range 64, 100° | 18 dmg, kb 160 | 3 s |
| Quick | Test Ground Burst | GROUND_CIRCLE | range 160, r 40, cast 0.3 s | 22 dmg, kb 120 | 5 s |
| Instant | Test Linear Strike | LINE | 150 × 22 | 12 dmg, nhiều mục tiêu | 2 charge, 4 s/charge, recast 0.5 s |
| Instant | Test Self Heal | SELF | r 18, cast 0.8 s | hồi 25 HP | 8 s |

**Tạo kỹ năng mới:** New Resource → `SkillDefinition`, đặt `skill_id`, targeting, timing, effect → thêm vào `ClassDefinition.skills` của class (xem 2i). Không cần sửa controller; loại effect mới cần thêm nhánh trong `SkillEffectExecutor`.

Giới hạn: chưa có projectile, buff/debuff, CC, interrupt; cone lọc theo tâm Hurtbox (mục tiêu sát mép góc có thể không trúng); hủy vận sức không hoàn charge; indicator vẽ cùng thứ tự Y-sort với Player; chỉ Player dùng skill.

## 2i. Class, Mastery, Passive & Skill Progression [Đã triển khai, prototype]

Quy tắc đã chốt: một nhân vật mở khóa được nhiều class (qua NPC/nhiệm vụ/thử thách/khám phá — chưa triển khai), chỉ đổi class tại NPC/địa điểm quy định; mỗi class dùng nhiều loại vũ khí; đánh thường theo vũ khí, kỹ năng chủ động theo class; một **character level** dùng chung + **mastery** riêng từng class; kỹ năng có level và nhánh tiến hóa; đúng 4 ô (ultimate dùng chung); mỗi class có một **signature passive** cố định + passive bổ sung tự chọn. Điều kiện, tài nguyên, công thức và cân bằng **chưa chốt** — mọi số liệu dưới đây là placeholder.

```
features/character/
├── level_curve.gd        — LevelCurve (Resource): exp_to_next_level[]; dùng cho character level và mastery
├── level_progress.gd     — LevelProgress (RefCounted): level + EXP theo curve
├── character_level.gd    — CharacterLevel (Node, trên Player): level dùng chung
└── data/test_character_curve.tres
features/classes/
├── class_definition.gd   — ClassDefinition (Resource)
├── class_manager.gd      — ClassManager (Node, trên Player)
├── class_progress.gd     — ClassProgress (RefCounted): runtime state của một class đã mở khóa
├── skill_progress.gd     — SkillProgress (RefCounted): level / nhánh / cast mode của một kỹ năng đã học
├── passives/             — PassiveDefinition (Resource), PassiveController (Node, trên Player), data/*.tres
├── station/              — ClassTrainingStation (Interactable placeholder)
└── data/                 — test_fighter.tres, test_caster.tres, test_mastery_curve.tres
features/skills/progression/
├── skill_modifier.gd         — SkillModifier (Resource): cộng thêm thông số cho level / nhánh
└── skill_evolution_branch.gd — SkillEvolutionBranch (Resource)
ui/progression/progression_panel.gd/.tscn — ProgressionPanel
```

**Definitions** (dữ liệu, không chứa runtime state, không sửa lúc chạy):

| Resource | Field |
|---|---|
| `ClassDefinition` | `class_id` (ổn định), `display_name`, `description`, `allowed_weapon_type_ids`, `skills` (học được), `starting_skills` (học sẵn khi mở khóa + loadout mặc định theo ô, ≤ 4), `signature_passive`, `additional_passives`. `get_validation_errors()` / `is_valid()`: ID/tên rỗng, không có loại vũ khí, skill null/lỗi/trùng, starting ngoài skills, signature thiếu, passive trùng (kể cả trùng signature) |
| `PassiveDefinition` | `passive_id`, `display_name`, `description`, `effect_type` (`MAX_HEALTH` / `SKILL_POWER_PERCENT` / `MOVE_SPEED_PERCENT`), `amount`. `is_valid()` |
| `SkillDefinition` (thêm nhóm *Progression*) | `max_level`, `level_modifiers` (phần tử i áp dụng từ Lv i+2, cộng dồn), `evolution_branches`. `create_variant(level, branch_id, effect_percent)` trả **bản sao** đã áp modifier; `is_progression_valid()` kiểm tra mọi tổ hợp level × nhánh |
| `SkillModifier` | `short_name_override`, bonus cho `cast_range` / `radius` / `width` / `angle_degrees` / `cast_time` / `cooldown` / `max_charges` / `effect_amount` / `knockback`, đổi `indicator_color` |
| `SkillEvolutionBranch` | `branch_id` (duy nhất trong kỹ năng), `display_name`, `description`, `modifier` |
| `LevelCurve` | `exp_to_next_level: Array[int]`; level tối đa = size + 1 |

**Runtime state** (trong component của Player, chỉ ID + số):

- `CharacterLevel` — level/EXP dùng chung; `add_exp(n)`, `get_level()`, `get_exp()`, `get_exp_to_next()`; signal `level_changed`, `exp_changed`. Level chỉ tăng; ở level tối đa EXP không tích lũy. **Không** tự thưởng EXP khi hạ enemy, không tăng chỉ số.
- `ClassManager` — `_progress: class_id → ClassProgress` (chỉ tạo khi mở khóa): `mastery` (LevelProgress), `skills: skill_id → SkillProgress {level, branch_id, cast_mode}`, `unlocked_passive_ids`, `equipped_passive_ids`, `loadout` (4 skill_id). `to_dict()` trả dữ liệu thuần có `version` (chuẩn bị Save/Load; chưa có SaveManager).

**ClassManager API** (một active class tại một thời điểm):

- Class: `get_current_class()`, `get_current_class_id()`, `get_class_definition(id)`, `get_class_ids()`, `is_class_unlocked(id)`, `get_unlocked_class_ids()`, `unlock_class(id)` (API chung cho quest/NPC/khám phá sau này; không mở lặp), `can_switch_class(id)`, `get_switch_block_reason(id)`, `switch_class(id)`.
- Phiên đổi class: `open_switch_session(station, max_distance)`, `close_switch_session()`, `has_switch_session()`, `get_switch_station()`.
- Mastery: `get_mastery(id)` (null nếu chưa mở khóa), `add_mastery_exp(id, n)` — chỉ cộng cho đúng class đó.
- Kỹ năng: `learn_skill`, `is_skill_learned`, `get_skill_level`, `can_level_up_skill`, `level_up_skill`, `get_skill_branch`, `select_evolution_branch`, `get_skill_cast_mode`, `get_effective_skill`, `equip_skill(slot, skill_id)` (kỹ năng đang ở ô khác được chuyển ô), `unequip_skill(slot)`, `get_saved_loadout(id)`, `get_skill_runtime(id, skill_id)`, `reset_skill_runtimes()`.
- Passive: `get_signature_passive`, `unlock_passive`, `is_passive_unlocked`, `equip_passive`, `unequip_passive`, `get_equipped_passive_ids`, `get_passive_equip_block_reason`; export `additional_passive_limit` = **2** (thông số prototype).
- Signal: `class_unlocked`, `class_switched`, `mastery_changed`, `skill_learned`, `skill_level_changed`, `skill_evolved`, `passives_changed`, `switch_session_started/ended`, `progression_changed` (sau mọi thay đổi).
- `ClassManager.find_in(actor)` tìm component trên actor (không Autoload, không đường dẫn cứng).

**Đổi class tại điểm hợp lệ:** `ClassTrainingStation` (Interactable): nhấn **E** → `ClassManager.open_switch_session(station, session_range = 72)` → signal → World mở ProgressionPanel. Quyền đổi class kiểm tra ở gameplay layer (`get_switch_block_reason`): class tồn tại, đã mở khóa, khác class hiện tại, chưa chết, phiên hợp lệ (station còn, actor trong phạm vi). Phiên kết thúc khi đóng bảng, rời quá phạm vi (kiểm tra mỗi physics tick), station bị xóa, hoặc chết. Đi ngang qua không mở phiên. Mở khóa class thử nghiệm: `station.debug_unlock_class(manager, id)` — chỉ khi đang có phiên tại chính trạm đó và class nằm trong `debug_unlockable_classes`.

**Khi đổi class** (`_activate`): hủy ngắm/vận sức (`cancel_all`) và combo → gỡ 4 ô → đổi active class → tính lại passive (signature mới + passive bổ sung đã lưu của class mới) → khôi phục loadout đã lưu (bỏ ô không còn hợp lệ) với cast mode đã lưu theo kỹ năng → gỡ vũ khí không hợp lệ (không cấp vũ khí mới; Player hoạt động được khi không có vũ khí). Character level, mastery và tiến trình kỹ năng của mọi class giữ nguyên.

**Cooldown khi đổi class / đổi ô:** xem "Runtime integrity" ở 2j (từ TASK 11 runtime gắn với class + kỹ năng, không gắn với ô).

**Weapon compatibility:** `WeaponEquipment.set_equip_validator()` ← ClassManager: `weapon_type_id` phải thuộc `allowed_weapon_type_ids` của class đang dùng. Mọi đường trang bị (kể cả debug 1/2/3) đều qua `equip_weapon()` → bị từ chối, phát `equip_rejected` (World hiện thông báo). Không sửa WeaponDefinition / BasicAttackController.

**Kỹ năng:** `SkillLoadout.set_equip_validator()` ← ClassManager: kỹ năng phải thuộc class đang dùng **và** đã học. Tiến trình kỹ năng lưu **theo class** (cùng một SkillDefinition ở hai class có level/nhánh riêng) và độc lập với ô (gỡ không mất). Definition trong ô là bản sao `create_variant(level, nhánh, % sức mạnh passive)`; mọi effect vẫn qua SkillCastingController/SkillEffectExecutor/SkillAreaVisual nên indicator khớp vùng mới. Nhánh tiến hóa chọn/đổi tự do bằng debug — **chưa phải quy tắc gameplay**.

**Passive:** `PassiveController` nhận tập passive đang hoạt động và **tính lại tổng từ đầu** mỗi lần đổi (không cộng/trừ dần → không cộng trùng, không sót modifier); passive trùng ID tính một lần. Áp: max HP qua `HealthComponent.set_max_health_bonus()` (giữ tỉ lệ HP, kẹp [1, max] khi sống, đã chết vẫn 0 — không hồi sinh; `reset()` hồi đầy theo max mới), % sức mạnh kỹ năng (vào `create_variant`), % tốc độ (Player đọc `get_move_speed_multiplier()`). Signature không gỡ được, không chiếm ô bổ sung.

**Progression UI** (`ProgressionPanel`, góc trên phải): phím **P** (`debug_progression`) mở/đóng; **Esc / chuột phải** hoặc nút *Đóng* để đóng. Hiện character level/EXP, class đang dùng + đã mở khóa, mastery, signature, passive bổ sung (n/2 ô), kỹ năng (Lv, cast mode, nhánh, sát thương/hồi hiệu lực, nút xếp vào ô Q/C/V/X / Gỡ). Nút màu cam **[Debug]** (+EXP, +Mastery, Học, +Lv, Nhánh, Mở khóa passive/class) là công cụ thử nghiệm. Nút đổi class chỉ hiện khi có phiên tại trạm; bảng không tự quyết quyền. Bảng mở → `Player.set_combat_input_blocked(true)` (World nối), hủy ngắm/vận sức; đóng bảng kết thúc phiên. CombatHUD thêm dòng `Class: … · Lv n`.

**Dữ liệu prototype** (không phải class chính thức):

| Class | Vũ khí | Kỹ năng (học sẵn **đậm**) | Signature | Passive bổ sung |
|---|---|---|---|---|
| Test Fighter (khởi đầu) | sword, heavy | **Arc Slash**, **Linear Strike**, Self Heal | Test Vigor: +30 max HP | Test Toughness +15 HP, Test Swiftness +15% tốc độ |
| Test Caster (mở khóa tại trạm) | dagger | **Ground Burst**, **Self Heal**, Linear Strike | Test Focus: +20% sức mạnh kỹ năng | Test Attunement +10% sức mạnh, Test Swiftness |

Level kỹ năng: Arc (max 3: +4 dmg; +4 dmg & −0.5 s hồi), Burst (max 3: +5 dmg; +8 bán kính), Line (max 2: +1 charge), Heal (max 2: +10 hồi, −0.3 s vận sức). Nhánh: Arc — *Quạt rộng* (+80°, −4 dmg) / *Chém xa* (+40 tầm, −40°); Burst — *Bùng rộng* (+24 bán kính, −6 dmg) / *Bùng tụ* (−16 bán kính, +16 dmg, +40 tầm). Character curve 100/150/220/300 (max Lv 5); mastery curve 60/90/130 (max Lv 4).

**Thêm class mới bằng dữ liệu:** New Resource → `PassiveDefinition` (signature + passive bổ sung) → New Resource → `ClassDefinition`, đặt `class_id`, loại vũ khí, `skills` / `starting_skills`, passive → thêm vào `ClassManager.classes` trên Player (và `debug_unlockable_classes` của một trạm nếu muốn mở khóa thử). Không cần sửa code. Kỹ năng có level/nhánh: điền nhóm *Progression* trong SkillDefinition.

**Chưa chốt / chưa triển khai:** điều kiện mở khóa class/kỹ năng/passive, nguồn EXP & mastery (chỉ có debug), công thức level, tài nguyên nâng cấp, quy tắc đổi/reset nhánh, quy tắc cooldown chính thức khi đổi class, số ô passive, ultimate, cây kỹ năng, NPC/quest, Save/Load. Debug reset **R** không đụng tới progression; chưa có nút reset progression.

## 2j. Combat Sandbox, enemy prototype & runtime integrity [Đã triển khai, thử nghiệm]

```
world/sandbox/
├── combat_sandbox.tscn     — World thứ hai (script world.gd, cùng cấu trúc container) dùng lại Player/Camera/UI
├── sandbox_map.tscn        — map 60×40 ô (TileSet + MapBounds có sẵn), sinh một lần bằng script ngoài project
├── scenario_controller.gd  — ScenarioController (Node cục bộ của scene, không phải manager toàn cục)
├── combat_scenario.gd      — CombatScenario (Node2D): vị trí = spawn Player; display_name, description, player_health_ratio
└── scenario_spawn.gd       — ScenarioSpawn (Marker2D): `scene` sinh ra khi tình huống bắt đầu
ui/debug/combat_debug_panel.gd/.tscn — CombatDebugPanel (F3)
```

**Truy cập:** Main Scene → nút **Combat Sandbox (thử nghiệm)**, hoặc mở `combat_sandbox.tscn` + F6. "Vào game" vẫn vào Test World. Sandbox không phải map chính thức.

**Bản đồ** (1920×1280 px; kích thước chỉ lấy từ MapBounds/GroundLayer → camera limit, zoom tối thiểu 1×): A. *Training* (trên trái, 4 bù nhìn: 1 đơn + 3 sát nhau); B. *Obstacle* (dưới trái, ba hàng đá/bụi có khe hở); C. *Enemy Arena* (phải, nền đất, viền bụi, lối vào ở đường ngang, vài cột đá); D. *Class Training* (quảng trường đá giữa: trạm class, bảng thông báo, spawn Player). Đường đất nối các khu.

**Enemy prototype** — một script `Enemy` (state IDLE / CHASE / ATTACK / RECOVERY / DEAD), khác nhau bằng dữ liệu + `AttackComponent`; mọi scene kế thừa `enemy_base.tscn` (Health, Hurtbox layer 6, HitFlash, HealthBar, Knockback, DebugView). Không phát hiện ngoài `detection_range`; di chuyển và knockback luôn qua `move_and_slide()` (bị vật cản chặn, có thể kẹt, không pathfinding); AI không sửa HP; chết → hủy đòn.

| Scene | movement_mode | HP | Đòn | Detection | Ghi chú |
|---|---|---|---|---|---|
| `simple_enemy` (Melee Chaser) | CHASE | 40 | Melee 10 dmg, tầm 26, windup 0.35 s, hồi 1.0 s | 150 | knockback bình thường |
| `stationary_attacker` | STATIONARY | 70 | Melee 14 dmg, 64×30, windup 0.7 s (telegraph tím), hồi 1.4 s | 120 | `strength_multiplier = 0` (không bị đẩy) |
| `ranged_enemy` | KEEP_DISTANCE | 30 | Ranged 8 dmg, tầm 170, windup 0.6 s, hồi 1.6 s, đạn 200 px/s, bay tối đa 230 | 220 | lùi khi Player gần hơn 130 × 0.75 |

- `AttackComponent` (base): `attack(direction)`, `can_attack()`, `is_attacking()`, `is_recovering()`, `cancel()`, `get_phase()`; hook `_on_windup_started/_on_active_started/_on_active_ended/_on_cancelled`. Hướng chốt lúc bắt đầu.
- Telegraph = đúng vùng tác động: MeleeAttack hiện chữ nhật của Hitbox khi windup; RangedAttack hiện đường bắn dài `projectile_range` × `telegraph_width`.
- `Projectile` (Area2D): bay thẳng, `collision_mask` = phe đối địch; trúng Hurtbox **một lần** qua `receive_damage(DamageInfo)` rồi biến mất; raycast layer `world` mỗi tick (không xuyên vật cản); tự hủy khi hết tầm; thuộc group `test_resettable` nên reset xóa đạn đang bay. Được thêm vào container của người bắn (EntityContainer).
- Phe giữ nguyên: Hitbox/đạn enemy chỉ dò layer 5 → enemy không đánh nhau.

**Tình huống thử nghiệm** (`Scenarios` trong sandbox; chọn trong Debug Panel): Tự do (5 enemy), Một mục tiêu đứng yên, Nhiều mục tiêu sát nhau, Một enemy cận chiến, Enemy đứng yên, Một enemy tầm xa, Nhiều enemy, Enemy gần vật cản, Bị hạ gục khi đang dùng kỹ năng (HP 15%), Đổi vũ khí giữa combo, Đổi class sau khi dùng kỹ năng. `start_scenario(i)`: xóa thực thể của tình huống cũ (giải phóng, không giữ tham chiếu) → `Player.set_spawn_position()` → `World.reset_test_state()` (Player, dummy, đạn) → sinh ScenarioSpawn vào EntityContainer (đặt vị trí trước `add_child`, gán `target`) → `entity_spawned` → `World.register_entity()` nối số sát thương/HitSpark. API: `restart()`, `reset_enemies()`, `get_active_enemy_count()`, `get_current_scenario()`.

**Thêm tình huống:** trong `combat_sandbox.tscn`, thêm Node2D con của `Scenarios` với script `combat_scenario.gd`, đặt vị trí (spawn Player), điền tên/mô tả; thêm con Marker2D với script `scenario_spawn.gd` và gán `scene` (vd. `ranged_enemy.tscn`). Không cần sửa code; nút xuất hiện tự động trong Debug Panel.

**Reset:** R / nút Reset = `World.reset_test_state()` (Player về spawn của tình huống, HP đầy, hủy đòn/cast, hồi đầy runtime kỹ năng; enemy về điểm sinh; đạn bị xóa; camera nhảy về Player). "Chạy lại tình huống" sinh lại enemy. Không reset character level, mastery, class đã mở khóa, tiến trình kỹ năng.

**Runtime integrity (quy tắc kỹ thuật tạm, chưa phải quyết định gameplay):**

- Mỗi class + kỹ năng đã học có **đúng một** `SkillRuntime`, tạo lúc học và lưu trong `ClassProgress.runtimes` (tách khỏi `SkillProgress` là level/nhánh/cast mode).
- `SkillLoadout.equip_runtime(slot, runtime)` cắm runtime có sẵn vào ô (không tạo mới). Gỡ/trang bị lại/chuyển ô hay đổi class qua lại **không** hồi charges hay xóa cooldown; cast mode đi theo runtime.
- `ClassManager._physics_process` tick mọi runtime của mọi class (SkillLoadout chỉ tick runtime tự tạo bằng `equip_skill`) → cooldown của class không hoạt động vẫn giảm theo thời gian gameplay, charges hồi theo quy tắc hiện có, không nhận thêm ngoài tiến trình đó.
- Đổi class vẫn hủy ngắm/vận sức (`SkillCastingController` giữ tham chiếu runtime đang vận sức nên `is_casting` không bị treo khi ô bị gỡ).
- Lên level/tiến hóa/đổi passive chỉ thay definition (`set_definition`), giữ cooldown/charges. Không có global cooldown.
- Reset thử nghiệm (R, chạy lại tình huống) hồi đầy runtime — chỉ là công cụ debug.

**Feedback:** HitSpark (vòng + 4 tia, 0.22 s, tự giải phóng) tại điểm trúng, vòng lớn màu cam khi bị hạ gục; telegraph enemy; state RECOVERY. `EnemyDebugView` (bật bằng Debug Panel): vòng `detection_range`, vòng tầm đánh, vòng lùi (ranged), tên state.

**Combat Debug Panel** (F3, `debug_combat_panel`; bên trái, dưới HUD; ẩn mặc định): HP, class, vũ khí (+ type), 4 ô (mode, charges, cooldown), số enemy còn sống / đã sinh, số đạn, FPS (làm mới 5 lần/giây); nút Hồi đầy HP (`heal()`), Reset enemy, Chạy lại tình huống, Reset (R), danh sách tình huống, công tắc debug info. Chỉ gọi public API, không sửa HP trực tiếp.

**Điều phối input/UI:** Progression Panel (P, phải) chặn input combat khi mở (là menu). Debug Panel **không** chặn — để vừa đánh vừa quan sát; click trên panel do GUI nhận (không xuyên thành đòn đánh/xác nhận ngắm), F3 không phải phím kỹ năng. Hai bảng ở hai bên màn hình, không chồng nhau. Esc/chuột phải đóng Progression; F3 đóng Debug.

**Hiệu năng:** không duyệt scene tree mỗi frame (Debug Panel đếm đạn 5 lần/giây; ScenarioController giữ danh sách thực thể đã sinh); đạn và HitSpark có thời gian sống giới hạn. Đo trong tình huống "Nhiều enemy" (windowed, máy dev): 60 FPS.

**Giới hạn:** không pathfinding (enemy kẹt sau vật cản); ranged chỉ lùi thẳng, có thể lùi vào tường; đạn không có hiệu ứng nổ; knockback Player chưa có; reset thử nghiệm hồi cooldown; tình huống "bị hạ gục khi vận sức" phụ thuộc nhịp enemy (thao tác thủ công); Debug Panel và sandbox chỉ dành cho kiểm thử.

## 2k. Environment Visual Foundation & Prototype — isometric [Đã triển khai, prototype — TASK VISUAL-01, VISUAL-02, VISUAL-02.1, VISUAL-02.2]

Định hướng đồ họa môi trường: **High-Resolution Hand-Painted 2D, góc isometric dimetric 2:1** (VISUAL-02 thay góc oblique của VISUAL-01). Thông số đầy đủ + hướng dẫn gen art: [visual/environment-style-guide.md](visual/environment-style-guide.md). Art: phần lớn đã là **art vẽ tay** (gen AI bằng ChatGPT + hậu kỳ, commit `780e684` + `ruin_arch.png` ở VISUAL-02.2), cùng kích thước file với placeholder; còn **sinh bằng code** (`tools/placeholder_art/`): decal bóng/đốm sáng mềm (`shadow_soft`, `light_patch`, `canopy_shadow`), `fx/*` và tile lưới logic. Danh sách + quy trình: style guide mục 11.

**Map cũ giữ góc cũ:** `world/maps/test_map/` và `world/sandbox/` (top-down/oblique, pixel art) chưa chuyển sang isometric — sẽ làm ở task sau. Các thay đổi chung đều có mặc định giữ hành vi cũ (`Player.vertical_speed_scale = 1`, `GameCamera.zoom_step = 1`).

```
world/environment/
├── iso/        iso_projection.gd (IsoProjection: to_screen/to_grid, tile 64×32, tầng 64 px), iso_map_bounds.gd (IsoMapBounds),
│               footprint_sorted_sprite.gd (@tool FootprintSortedSprite), iso_actor_adapter.gd (IsoActorAdapter)
├── elevation/  elevation_map.gd, elevated_terrain.gd (@tool), elevated_deck.gd (@tool), elevation_connector.gd, elevation_agent.gd
├── props/      environment_prop.gd, occlusion_fader.gd + 15 scene prop (footprint thoi/ellipse 2:1)
├── terrain/    terrain_ground/terrain_path.gdshader (toạ độ lưới iso), decal_scatter.gd (@tool), terrain_logic.gd + tileset isometric, material .tres
├── water/      stream.gd, footbridge.gd (@tool), water_surface/waterfall.gdshader + material
├── atmosphere/ ambient_drift.gd
└── art/        PNG isometric (phần lớn vẽ tay; bóng mềm, fx, tile logic sinh bằng code)
world/environment_prototype/environment_prototype.tscn — khu "Glade" isometric 40×40 ô (script world.gd)
ui/debug/environment_debug_hud.gd/.tscn · tests/environment/test_environment_prototype.gd · tools/placeholder_art/
```

**Truy cập:** Main Scene → **Environment Prototype (Visual 01)**, hoặc mở `environment_prototype.tscn` + F6.

**Phép chiếu:** `x = (i − j)·32, y = (i + j)·16 − z`. Physics/collision ở không gian màn hình; footprint mặt đất là thoi/ellipse 2:1. Di chuyển: WASD theo màn hình, Player trong map iso có `vertical_speed_scale = 0.7` (VISUAL-02.2; 0.5 là tốc độ đều tuyệt đối trên mặt đất + nhấn chéo đi đúng trục lưới, nhưng đi dọc cảm giác chậm). Hướng nhìn/đòn đánh theo con trỏ như cũ. `IsoActorAdapter` (chỉ trong map iso): bóng ellipse 2:1, marker hướng nhìn (`facing_pivot`, nếu actor có) nằm trên mặt đất (nén dọc 0.5), collision thân ellipse 14×7; gọi `set_ground_squash(0.5)` cả trên `PlayerSprite` để chọn hướng sprite theo mặt đất (CHAR-01 bỏ marker của Player).

**Bố cục Glade:** khối đất nổi trên vực (`LandMass`, vách vực 192 px ở mép SE/SW, mép cỏ ở NW/NE, tường `LandEdge`); plateau tầng 1 với **quảng trường đá lát thoi** + tàn tích (vòm, cột, đá rune) và **đường đất chạy xéo** dọc mép vách; **cầu thang đá** chéo trên vách SW; **lối đi tầng 1 trên vòm** sang mỏm đá phía đông, đường nhánh tầng 0 **chui dưới vòm**; suối + **cầu gỗ chéo** ở tầng thấp, suối **đổ thác qua mép vực** có sương; phông xa parallax (núi, lâu đài mờ) + nền sương lấp đầy (`AbyssHaze`) nên camera ra mép không lộ khoảng trống.

**Cây scene (rút gọn):** `Environment` (SunTint, ScenicBackground z −100, Atmosphere z 40, Foreground z 50) → `MapContainer/GladeMap` (z −20: TerrainLogic ẩn, MapBounds = IsoMapBounds, AbyssHaze z −110, LandMass, LandEdge, Transitions, Paths/GroundPlane, Stream/GroundPlane, Footbridge, Waterfall + sương, bóng AO, Details) → `EntityContainer` (Y-sort: `Elevation` [Plateau, Outcrop, StoneBridge, CliffStairs, UpperGroundDetail z 4], `Props`, Player + ElevationAgent + IsoActorAdapter, NoticeBoard, TrainingDummy, SimpleEnemy + agent + adapter) → EffectContainer, CameraContainer (zoom 1–3×, bước 0.25), UILayer.

**Terrain logic vs visual:** `TerrainLogic` là TileMapLayer isometric (DIAMOND_DOWN, 64×32, `position = (−32, 0)`), phân loại theo vị trí màn hình; ẩn khi chơi; `IsoMapBounds.get_map_rect()` = khung bao lưới thoi + lề + phần vách vực → giới hạn camera. Hình ảnh mặt đất = texture top-down chiếu lên mặt phẳng iso trong shader (toạ độ lưới), overlay Line2D trong node `GroundPlane` (scale y 0.5). Collision lấy từ hình học logic.

**Elevation (Discrete Tiers):** giữ nguyên kiến trúc VISUAL-01 (layer 7/8, z = tier × 10, chỉ đổi tầng qua connector). Thay đổi cho iso:

- `ElevatedTerrain`: khối cao lộ 2 mặt vách (SW + SE); đoạn vách ≤ 32 px neo tại điểm chân vách cao nhất của đoạn; texture vách lặp theo chiều cao; `back_lip` cho mép sau.
- `ElevationConnector`: hành lang hình bình hành `bottom`/`top`/`half_width` (cầu thang chéo), phân tầng khi rời bằng phép chiếu lên trục bottom → top.
- `ElevatedDeck.deck_polygon` (hình bình hành iso) thay cho Rect2.
- `FootprintSortedSprite`: cắt sprite lớn thành lát 16 px, mỗi lát neo tại mép trước của footprint → lối đi trên vòm/cầu thang/vòm/tường dài chạy chéo vẫn che/đè đúng.

**Combat trên map isometric [VISUAL-02.1]:**

- `GroundSpace` (`features/combat/ground_space.gd`): toán học mặt phẳng đất với `squash` (1 = map cũ, 0.5 = iso). Tầm đánh, bề rộng, bán kính, tầm bay đo **trên mặt đất**; hình tròn trên đất = ellipse 2:1 trên màn hình.
- Component combat có `set_ground_squash(s)`: `BasicAttackController`, `AttackComponent` (`MeleeAttack`, `RangedAttack`), `SkillCastingController`, `Enemy`. Khi `s < 1`: node không xoay theo hướng đòn; hitbox/visual là hình chữ nhật trên mặt đất (polygon màn hình), knockback theo hướng mặt đất; `Projectile` bay với tốc độ/tầm đo trên mặt đất, thân ellipse; `SkillTarget.ground_squash` → executor dựng vùng ellipse/hình bình hành, góc quạt so trên mặt đất, indicator vẽ đúng hình đó. `s = 1` đi đúng nhánh code cũ → `test_map`/sandbox không đổi hành vi.
- `IsoActorAdapter` (chỉ map iso) gọi `set_ground_squash(0.5)`, dời gốc các node đòn đánh/kỹ năng từ ngang ngực về chân, đổi Hurtbox sang ellipse 2:1 bán kính 10 tại chân, đặt `vertical_speed_scale` (export trên adapter, mặc định **0.7** từ VISUAL-02.2, trước là 0.5) cho Player và enemy. Enemy: `vertical_speed_scale` (export, mặc định 1, cùng cơ chế Player) + khoảng cách AI đo trên mặt đất.
- **Lọc theo tầng:** `DamageInfo.tier_mask` / `Hurtbox.tier_mask` (bit `1 << tầng`, 0 = không lọc — map cũ). Chỉ trúng khi hai mask giao nhau. `ElevationAgent` gọi `set_elevation(tier_mask, obstacle_mask, ground_z)` trên mọi node con có hàm đó (duck-typing — module combat không phụ thuộc world). Đòn đánh, kỹ năng (`SkillEffectExecutor.execute(..., tier_mask)`), đạn (DamageInfo của người bắn) đều mang tầng người tấn công. Bù nhìn cũng có ElevationAgent.
- **Hành lang cầu thang:** thực thể đang chuyển tầng có `tier_mask = tầng dưới | tầng trên` của connector → đánh trúng và bị đánh bởi **cả hai tầng**; `obstacle_mask = 0` (đạn bắn ra không bị vách chặn ngay tại chỗ); indicator vẽ ở tầng trên.
- **Indicator kỹ năng:** `SkillAreaVisual` là `top_level` nên `z_index` tuyệt đối; `SkillCastingController.set_elevation()` đặt z = `tier × 10 − 3` (trên mặt đất + chi tiết mặt đất của tầng, dưới occupant/prop của tầng).
- **Đạn và vách:** raycast của đạn dùng `world | obstacle_mask` (layer vách của tầng người bắn) → đạn tầng 0 bị vách khối tầng 1 chặn. Vật cản trong group `projectile_passable` (collision mặt nước của `Stream`) không chặn đạn.
- **Debug:** `EnvironmentDebugHud` có thanh trượt "[Debug] Tốc độ dọc" (0.3–1.0) chỉnh `vertical_speed_scale` của Player và mọi enemy lúc chạy; không lưu.

**Kiểm thử** (headless, thoát mã 1 nếu fail; lệnh chạy trong README và `tools/README.txt`): `tests/environment/test_iso_combat.gd` — 30 ca: tỉ lệ vận tốc dọc enemy = Player (map cũ = 1), tầm đánh/vùng kỹ năng/tầm bay đạn đo trên mặt đất, lọc tầng cho đòn đánh/kỹ năng/đạn, hành lang cầu thang thuộc cả hai tầng, z indicator theo tầng, đạn bị vách chặn và bay qua nước, hồi quy map cũ (tầm theo màn hình). `tests/environment/test_environment_prototype.gd` — 17 ca: lên/xuống cầu thang, vách chặn tầng 0 (SW, SE) và tầng 1 (SW, SE), đi trên vòm sang mỏm đá, chui dưới vòm, nước chặn, qua cầu gỗ, thân cây chặn, mép vực SW, mép NE, fade sau cây / không fade trước cây, cầu mờ khi đứng dưới gầm / không mờ khi đứng trên cầu. Render (máy dev, zoom 1×): 60 FPS, ~127 draw call, ~26 MB texture.

**Tinh chỉnh sau production art [VISUAL-02.2]:**

- Đường đất: `terrain_path.gdshader` thêm `sand_color`/`sand_mix` (pha màu cát → sáng, giảm tương phản đốm đậm) và `edge_detail` (noise mép 2 tầng → cỏ lấn). `path_dirt.tres`: tint `(1,1,1)` → `(1.05,1.02,0.97)`, `sand_mix` 0.45, `edge_start` 0.5 → 0.3, `edge_noise_strength` 0.35 → 0.55, `edge_noise_scale` 3 → 2, `rim_darken` 0.2 → 0.06. Bề rộng Line2D (tile): chính 1.2 → 1.7, nhánh 1.0 → 1.4, trên plateau 1.1 → 1.5. `shore_mud.tres` giữ nguyên (mặc định shader mới cho kết quả cũ). Không đổi collision; lưới `TerrainLogic` vẫn phân loại "dirt" trong bán kính 0.6 tile quanh tâm đường (chỉ dùng cho HUD debug).
- Ánh sáng: `SunTint` `(1,0.97,0.9)` → `(1,0.96,0.86)`; tia nắng màu `(1,0.95,0.8)` → `(1,0.88,0.62)`, alpha 0.07–0.10 → 0.10–0.13; đốm nắng `(1,0.95,0.8)` α 0.16 → `(1,0.9,0.66)` α 0.2; sương suối/thung lũng ngả ấm nhẹ. Giá trị trong style guide mục 7.
- Cửa sổ mặc định 1920×1080; **viewport gốc giữ 1152×648**: stretch `canvas_items` phóng đều ×1.67 nên khung hình, zoom camera (test_map 2×, Combat Sandbox 2×, Environment Prototype 2×, bước 0.25) và bố cục UI không đổi. Đổi viewport gốc sang 1920×1080 cho ảnh y hệt nếu nhân mọi zoom ×1.67 (art vẽ tay chỉ có 2 texel/px nên không nét hơn), còn nếu giữ zoom thì nhân vật nhỏ đi 1.67× so với ảnh tham chiếu, UI nhỏ lại và map pixel art cũ phải chỉnh zoom — không có lợi.
- Script dựng `tools/glade/build_glade_prototype.gd` đã cập nhật cùng giá trị (chạy lại ra đúng scene hiện tại).

**Giới hạn:** enemy không pathfinding (kẹt ở chân vách khi Player lên tầng cao); combat có chiều cao như nhau cho mọi thực thể (không có độ cao bay/nhảy — đạn bay sát mặt đất, mọi vùng đòn nằm trên mặt đất); đạn tầng 1 bắn ra mép plateau bị tường mép tầng 1 chặn (không bắn xuống tầng 0 được — cũng không trúng do lọc tầng); `EnemyDebugView` (vòng detection, chỉ bật trong sandbox) vẫn vẽ hình tròn màn hình; số sát thương/HitSpark hiện tại chân vì Hurtbox iso nằm ở chân; sprite nhân vật phải thấp hơn 64 px; vật cao tầng 0 không được chồng lên mặt tầng 1; mép đáy vách vực là đường thẳng tan vào sương (chưa có chiều sâu thật); thác là shader đơn giản (VISUAL-03).

## 2l. Item, Inventory, Rương, Vật phẩm trên đất, Save/Load [Đã triển khai, prototype — TASK M1]

Mốc M1 của lộ trình ([design/game_design.md](design/game_design.md) mục 6). Nền cho các hệ thống sau (sinh tồn, chế tạo, trồng trọt, NPC, nhiệm vụ). Quy tắc: dữ liệu thiết kế (`.tres`) chỉ đọc; trạng thái người chơi là Dictionary/JSON riêng; mọi thứ được lưu có **ID string ổn định** (không lưu đường dẫn node/scene).

```
features/items/      item_definition.gd (ItemDefinition), item_database.gd (ItemDatabase), item_stack.gd (ItemStack)
                     data/ (10 item thử + item_database.tres), icons/ (placeholder sinh bằng tools/item_icons/)
features/inventory/  inventory.gd (Inventory), equipment_slots.gd (EquipmentSlots)
                     pickup/ item_pickup.gd/.tscn (ItemPickup), item_pickup_layer.gd (ItemPickupLayer)
                     chest/  chest.gd/.tscn (Chest)
ui/inventory/        inventory_window.gd/.tscn (InventoryWindow), item_slot_view.gd (ItemSlotView), pickup_toast.gd/.tscn (PickupToast)
save/                save_service.gd — Autoload `SaveService` (duy nhất trong project)
world/maps/          map_catalog.gd/.tres (MapCatalog: map_id → scene)
```

**Item data** — `ItemDefinition` (Resource): `id`, `display_name`, `description`, `icon`, `category` (MATERIAL, FOOD, TOOL, WEAPON, ARMOR, SEED, QUEST, MISC), `max_stack`, `sell_price`, `tags`, `equip_slot` (`&"weapon"` / `&"head"` / rỗng), `weapon` (WeaponDefinition có sẵn, cho item vũ khí). `get_validation_errors()`: id/tên rỗng, max_stack < 1, item vũ khí thiếu weapon, item trang bị phải max_stack 1. `ItemDatabase` (Resource, **không phải Autoload** — gán bằng export cho Inventory, EquipmentSlots, pickup layer, như ClassManager nhận danh sách class): `get_item(id)`, `get_max_stack(id)`, `find_by_weapon(weapon)`; index dựng ở lần tra đầu, lúc đó `push_error` mọi lỗi (item null, item lỗi, **id trùng**, **id thiếu**); item lỗi/trùng không vào index. Item thử: gỗ, đá, thảo dược, quả mọng, thịt sống, 3 vũ khí (item id = weapon_id: test_sword/dagger/heavy), mũ thử, mảnh cổ vật (quest). Icon placeholder: `tools/item_icons/generate_item_icons.gd` (ô màu theo loại + chữ cái đầu, font bitmap 5×7 trong code).

**Inventory** (Node component, logic thuần, không biết UI) — N ô (`size`), mỗi ô `ItemStack` (`item_id`, `count`, `data` dự phòng độ bền…; chỉ gộp khi cùng id + cùng data) hoặc trống. API: `add(id, n) -> số dư` (lấp stack cũ trước, rồi ô trống), `add_stack`, `add_to_slot`, `remove(id, n) -> số đã bớt`, `remove_at(slot, n)`, `replace_at`, `move` (trống → chuyển, cùng loại → gộp, khác → đổi chỗ), `swap`, `merge`, `split(slot, n)` / `split_half`, `transfer_to(slot, other, slot)` (rương ↔ túi), `quick_transfer(slot, other)`, `has`, `count_of`, `space_for`, `first_empty_slot`, `is_full`; signal `changed` (một lần mỗi thao tác). Getter trả bản sao. `to_dict()` / `load_dict()` (bỏ qua có cảnh báo: item không tồn tại, ô ngoài phạm vi/trùng; kẹp theo max_stack). Player: 24 ô; rương: 20 ô.

**Trang bị** — `EquipmentSlots` (trên Player): ô `weapon`, `head`. `equip_from_inventory(slot, [ô])` (món đang mặc đổi chỗ về đúng ô túi đó), `unequip_to_inventory(ô, [slot])`, `get_equip_block_reason()` (sai ô, item lạ, luật vũ khí của `WeaponEquipment` — tức luật class 2i). Ô weapon **đồng bộ hai chiều** với `WeaponEquipment`: trang bị item → `equip_weapon(item.weapon)`; vũ khí đổi từ nơi khác (phím debug 1/2/3) → ô nhận item tương ứng (`find_by_weapon`; item cũ bị bỏ — chỉ là debug); vũ khí bị gỡ (đổi class) → item về túi, túi đầy thì `overflow_handler` (World: vứt xuống đất). Mũ chỉ lưu + hiển thị (chưa chỉ số/ngoại hình).

**Vật phẩm trên đất** — `ItemPickup` (Node2D, origin = chân, Y-sort; icon nổi lên xuống + bóng; `ElevationAgent` con → z theo tầng). `ItemPickupLayer` (một node/map, trong cây Y-sort của EntityContainer, group `saveable`, id `world_items`): mỗi physics tick, pickup **cùng tầng** trong `magnet_radius` 36 px (đo trên mặt đất, `ground_squash` 0.5 ở Glade) bị hút về Player, nhặt khi ≤ `collect_radius` 8 px; túi đủ một phần → nhặt phần vừa; hết chỗ → không hút, `pickup_blocked` (giãn cách 2 s). Pickup đặt sẵn có `pickup_id` (kiểm tra trùng lúc `_ready`); đã nhặt → vào `collected`, không xuất hiện lại sau khi load. `spawn_drop(stack, vị trí, tầng)` cho đồ vứt ra; pickup vứt ra "chưa armed" tới khi Player ra khỏi vùng hút (không nhặt lại ngay).

**Rương** — `Chest` (Interactable, phím E): `chest_id`, `starting_items` (item → số lượng, nội dung ban đầu), Inventory con 20 ô. Tương tác phát `open_requested(chest)`; World nối vào `InventoryWindow.open_chest`. Save id `chest:<chest_id>`.

**UI** — `InventoryWindow` (UILayer, style tạm): `inventory_toggle` (**I** / **Tab**) mở/đóng, `ui_cancel` (**Esc**) đóng. Bảng túi 6×4 + ô Vũ khí/Mũ; mở rương thì thêm bảng rương 5×4. Kéo thả giữa ô (túi ↔ túi/rương/trang bị), **chuột phải** = tách nửa stack, **Shift+click** = chuyển nhanh túi ↔ rương, **nhấp đúp** = trang bị/tháo, kéo ra ngoài cửa sổ = vứt xuống đất dưới chân (`drop_requested` → `World.drop_item`), tooltip tên/loại/mô tả. Đi xa rương > 80 px → tự đóng. Khi cửa sổ (hoặc Progression Panel) mở: `World._refresh_combat_block()` → `Player.set_combat_input_blocked(true)` (khóa đánh thường + kỹ năng); **di chuyển vẫn được** (giống Progression Panel; rương tự đóng khi đi xa). `PickupToast`: "+3 Gỗ" (cộng dồn khi nhặt liên tiếp), "Túi đầy — không nhặt được.".

**Save/Load** — `SaveService` (Autoload duy nhất, `save/save_service.gd`). Không biết chi tiết hệ thống: node trong group **`saveable`** có `get_save_id() -> String`, `save_state() -> Dictionary`, `load_state(Dictionary)`, tùy chọn `is_save_global() -> bool` (Player: true — đi theo người chơi qua mọi map; còn lại thuộc map hiện tại). Map lưu được = scene hiện tại là World có `map_id` (export mới) có trong `MapCatalog` (`glade` = Environment Prototype, `test_map` = world.tscn; Combat Sandbox không lưu).

| | |
|---|---|
| File | `user://saves/slot_<n>.json` (+ `slot_<n>.json.bak`) — M1 chỉ dùng slot 1 |
| Cấu trúc | `{schema_version, saved_at, playtime, map_id, global: {save_id: state}, maps: {map_id: {save_id: state}}}`; trạng thái map khác đã có trong phiên được giữ khi lưu |
| Ghi an toàn | ghi `.tmp` → đổi file cũ thành `.bak` → đổi `.tmp` thành file chính |
| Đọc | JSON lỗi / không phải object / thiếu file → thử `.bak`; cả hai hỏng → `failed`, không crash, giữ scene hiện tại. Field gốc thiếu/sai kiểu → mặc định (cảnh báo); field của từng hệ thống do hệ thống đó tự mặc định |
| Version | `SCHEMA_VERSION = 1`; `migrate()` chạy từng bước `register_migration(from, callable)` (khung, chưa có migration thật); save mới hơn bản game → từ chối |
| Tải | `load_game(slot)`: đọc → `change_scene_to_file(map)` (scene mới hoàn toàn) → chờ `scene_changed` + 1 frame (setup hoãn của map chạy xong) → `apply()` → `loaded`. World nghe `loaded`: camera nhảy về Player, thông báo |
| Kích hoạt | **F5** (`quick_save`) lưu nhanh, **F9** (`quick_load`) tải nhanh (debug, xử lý trong World); Main menu **Tiếp tục** (slot 1, mờ nếu chưa có save; các nút khác gọi `new_session()`); tự lưu khi đóng cửa sổ (`NOTIFICATION_WM_CLOSE_REQUEST`, nếu đang ở map lưu được) |
| playtime | cộng dồn khi scene hiện tại là map lưu được |

Nội dung lưu M1: `global.player` = vị trí, tầng (`ElevationAgent.set_tier` mới), HP (`HealthComponent.restore` mới; HP ≤ 0 → hồi đầy), `CharacterLevel`, `ClassManager.to_dict()` (class đã mở, class đang dùng, mastery, kỹ năng đã học + level/nhánh/cast mode, passive, loadout — khôi phục bằng `ClassManager.load_dict()` mới; cooldown/charges không lưu), trang bị, túi. `maps.<map_id>` = `chest:<id>` (nội dung rương), `world_items` (`collected` + `dropped`). Thứ tự khôi phục trong Player: level/class (passive đổi max HP) → trang bị (luật vũ khí theo class) → túi → HP → vị trí/tầng.

Ví dụ (rút gọn từ file thật):

```json
{
  "schema_version": 1, "saved_at": "2026-10-20 00:17:07", "playtime": 312.4, "map_id": "glade",
  "global": {"player": {
    "position": [-160.0, 886.4], "tier": 0, "health": 105, "level": {"level": 1, "exp": 0},
    "classes": {"version": 1, "active_class": "test_fighter", "classes": {"test_fighter": {"mastery": {"level": 1, "exp": 0}, "skills": {"test_arc_slash": {"level": 1, "branch": "", "cast_mode": 0}}, "loadout": ["test_arc_slash", "test_linear_strike", "", ""], "unlocked_passives": [], "equipped_passives": []}}},
    "equipment": {"version": 1, "slots": {"weapon": {"id": "test_sword", "count": 1}, "head": {"id": "test_helmet", "count": 1}}},
    "inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 5}]}}},
  "maps": {"glade": {
    "chest:glade_chest": {"inventory": {"version": 1, "size": 20, "slots": [{"slot": 0, "id": "berry", "count": 3}]}},
    "world_items": {"version": 1, "collected": ["glade_wood_1"],
                    "dropped": [{"id": "herb", "count": 2, "position": [-130.0, 892.4], "tier": 0}]}}}
}
```

**Trong Glade (Environment Prototype):** `EntityContainer/Chest` (`glade_chest`: 3 quả mọng, dao găm, 10 gỗ) cạnh đường đất gần spawn; `EntityContainer/Items` với 7 pickup (gỗ, đá, thảo dược, quả mọng, thịt sống, mũ ở tầng 0; mảnh cổ vật trên quảng trường tầng 1). Script dựng `tools/glade/build_glade_prototype.gd` đã thêm phần này. test_map có `Items` (để vứt đồ) + UI, không có pickup đặt sẵn.

**Kiểm thử:** `tests/inventory/test_inventory.gd` (52 ca: database hợp lệ + phát hiện id trùng/rỗng/null/vũ khí thiếu weapon; add/stack/tràn/số dư khi đầy/remove/move/swap/merge/split/transfer/quick transfer; to_dict/load_dict với dữ liệu lỗi; trang bị + đồng bộ WeaponEquipment). `tests/save/test_save_load.gd` (57 ca: nhặt khi chạm/hút, ngoài tầm, túi đầy + thông báo, khác tầng, đồ vứt; rương mở bằng E, khóa combat, tự đóng; thao tác cửa sổ; vòng lưu → đổi scene → tải đủ mọi phần; `.bak`/`.tmp`; file hỏng → `.bak`/báo lỗi; field thiếu → mặc định; schema mới hơn/migration; tự lưu khi đóng; Sandbox không lưu). Test là SceneTree script được biên dịch **trước** khi Autoload đăng ký: không dùng tên `SaveService` trực tiếp (preload script + `/root/SaveService`) và nạp scene trong `call_deferred` (đã sửa `test_environment_prototype.gd` + script dựng Glade theo cách này).

**Giới hạn:** một slot (chưa có UI chọn slot); ô weapon nhận vũ khí từ phím debug mà không trả item cũ về túi; cooldown/charges kỹ năng, enemy (HP/vị trí), bù nhìn không được lưu (về trạng thái của scene khi tải); không có hotbar/chế tạo/ăn uống/độ bền/tiền/chỉ số trang phục; icon là placeholder; `MapCatalog` mới có 2 map, chưa có chuyển map trong game; vứt đồ luôn rơi dưới chân Player; pickup kiểm tra tầng nhưng không kiểm tra vật cản giữa Player và pickup.

## 2m. Thời gian, ngày/đêm, sinh tồn, ngủ, chết & hồi sinh [Đã triển khai, prototype — TASK M2 (gộp M2.1, thiết kế v0.2)]

Mốc M2 theo [design/game_design.md](design/game_design.md) v0.2 (mục 3.4, 4.3–4.6): "sống sót qua một ngày một đêm". **Không có chỉ số Thể lực/Mệt** (bỏ theo v0.2 trước khi ra bản nào — save chưa từng có field energy nên không cần migration v2 → v3).

```
features/time/       game_clock.gd (GameClock), time_settings.gd/.tres (TimeSettings)
features/survival/   activity.gd (Activity.Kind), mana_*.gd/.tres, stamina_*.gd/.tres, hunger_*.gd/.tres,
                     buff_definition.gd, buff_component.gd, item_user.gd (ItemUser)
                     rest/   rest_spot.gd (RestSpot), bed.gd/.tscn, tent.gd/.tscn, sleep_controller.gd, sleep_settings.gd/.tres,
                             placement_check.gd (PlacementCheck)
                     death/  death_bag.gd/.tscn (DeathBag), death_controller.gd (DeathController)
features/items/      consumable_effect.gd (ConsumableEffect) + item mới: bread, grilled_meat, lantern, tent
entities/player/     mobility_settings.gd + player_mobility.tres (chạy / né)
world/environment/time/  day_night_lighting.gd, day_night_settings.gd/.tres, vision_light.gd (VisionLight)
ui/survival/         sleep_overlay.gd (SleepOverlay), death_bag_marker.gd (DeathBagMarker)
save/                save_migrations.gd (SaveMigrations: v1 → v2)
```

**Đồng hồ** — `GameClock` (Node trong World, **không** Autoload; group `saveable`, global id `clock`). `total_minutes` tính từ 0:00 ngày 1; ngày mới lúc **0:00**. Chạy trong `_process` → dừng khi `SceneTree.paused` (mở túi đồ không pause; game chưa có menu hệ thống — đã chốt với chủ dự án). `advance(phút, sleeping)` là đường duy nhất làm thời gian trôi: phát `time_passed(phút, sleeping)`, `hour_changed` cho **từng** giờ vượt qua, `day_started(day)` mỗi nửa đêm, `phase_changed` cho **từng** mốc phase (dawn 5:00 → day 7:00 → dusk 17:00 → night 19:00), `minute_changed`. Debug (chỉ build debug): **F7** bật/tắt tua ×10, **F8** +1 giờ.

**Ngày/đêm & tầm nhìn đêm** — `DayNightLighting` (một node/map) đọc GameClock mỗi frame: `darkness` 0 (ngày) → 1 (đêm), chuyển mượt (smoothstep) trong bình minh/hoàng hôn; `SunTint` (CanvasModulate) = ngày → hoàng hôn → đêm (M2: `(0.03, 0.035, 0.07)` gần đen; M3: ánh trăng `moonlight` 0.16 — xem 2n); node group `daylight_fx` (tia nắng, đốm nắng) mờ theo darkness; mọi `VisionLight` (group `vision_light`) sáng theo darkness. Phát `darkness_changed` cho quái đêm (M6).

- **Kỹ thuật:** `CanvasModulate` gần đen ban đêm (mọi thứ trên canvas của map — địa hình, quái, item — chìm vào bóng tối thật; UI ở CanvasLayer riêng không bị ảnh hưởng) + `PointLight2D` (M2: blend Add cộng sáng; M3 đổi sang Mix — 2n) sáng lại vùng quanh nguồn sáng. Texture là `GradientTexture2D` radial tạo bằng code (sáng đều tới `inner_ratio` 0.6 rồi mờ dần tới mép), node light nén dọc theo `ground_squash` → vùng sáng là **hình tròn trên mặt đất** (ellipse 2:1 trên map iso). Chọn vì: chạy sẵn trên renderer Compatibility (Light2D 2D hỗ trợ trên GLES3), không cần shader mask/SDF hay SubViewport, nguồn sáng mới chỉ là thêm một node; cùng một mô hình số (`VisionLight.cover_at`, `DayNightLighting.get_visibility / is_point_visible`) dùng cho logic + test.
- **Bán kính:** `DayNightSettings.base_vision_radius` 160 px mặt đất (≈ 3.5 ô lưới) — đủ thấy quái tới gần, phải chuẩn bị đèn/đi đường quen. Đèn lồng ở ô **offhand**: `ItemDefinition.light_radius` +96 (→ 256) + màu ấm `light_color`; chưa tốn dầu. Nguồn sáng thế giới: đá rune (VisionLight 140 px, xanh), đèn cạnh giường nhà (96 px, ấm).
- **Hiệu năng** (máy dev: AMD Radeon Graphics tích hợp, `gl_compatibility`, cửa sổ 1152×648, zoom 2×, tắt vsync): ngày 144 FPS, đêm 142 FPS, đêm + đèn lồng 131 FPS (vsync bật: 60 cố định cả ba).

**Chỉ số** (mỗi chỉ số một component, thông số trong Resource; Player có `ManaComponent`, `StaminaComponent`, `HungerComponent`, `BuffComponent`):

| Chỉ số / Resource | Mặc định | Lý do |
|---|---|---|
| Mana (`mana_settings.tres`) | max 100, hồi 4/s sau 1 s kể từ lần tiêu cuối | 4 kỹ năng thử tốn 10–25 → spam liên tục cạn trong ~10 s, nghỉ ~25 s là đầy: đánh nhau phải chọn chiêu |
| `SkillDefinition.mana_cost` | Arc Slash 15, Ground Burst 25, Linear Strike 10, Self Heal 20 | Tỉ lệ theo sát thương/hiệu quả; không đổi chỉ số combat khác. Thiếu mana: không cast, Skill Bar ghi "Thiếu mana (N)" + tô xanh |
| Stamina (`stamina_settings.tres`) | max 100, hồi 30/s sau 0.6 s; chạy **12/s** (M3; M2: 20/s); né 25/lần; kiệt sức (về 0) → chỉ chạy/né lại khi hồi ≥ 30 | Chạy liên tục ~8.3 s (M3: 20/s cạn quá nhanh), né 4 lần liền; hồi đầy ~3.5 s nên giữa các đợt đánh luôn có lại |
| Chạy / né (`player_mobility.tres`) | đi 160 px/s (giữ nguyên), Shift ×1.5 = 240; né 72 px mặt đất trong 0.2 s, bất tử 0.3 s, hồi né 0.5 s | Đi bộ giữ cảm giác cũ (đã chốt); né ≈ 2 lần bề rộng đòn kiếm để thoát đòn, i-frame dài hơn lướt một chút cho dễ canh |
| Đói (`hunger_settings.tres`) | 0–100; −4/giờ game khi thức, −2/giờ khi ngủ; chạy 0.08/s, né 0.5, mỗi đòn 0.15, mỗi kỹ năng 0.4; < 25: không hồi stamina; = 0: mất **6 % HP tối đa mỗi giờ game** (M3; M2: −1 HP mỗi 3 phút game); ≥ 95: "đang no" | Một ngày thức (~18 h) mất ~72 + hoạt động → 2–3 bữa/ngày; đói lả: đầy HP → chết sau ~13.9 phút thực (công thức ở 2n) — đủ chậm để kịp tìm đồ ăn |
| Ngủ (`sleep_settings.tres`) | ngủ 18:00 → trước 6:00; dậy 6:00; ngất lúc 2:00 (M3: tỉnh tại chỗ, đói −10); ngủ hồi HP **giường 100 % / lều 70 %** (M3; M2: 50 %) + 100% mana; hồi sinh 50% HP; mờ 0.8 s, "Ngày N" 1.5 s | Bám v0.2 (4.6): ngủ = qua đêm an toàn + hồi + tự lưu |
| Đồng hồ (`time_settings.tres`) | 1 ngày = 1200 s thực (20 phút), bắt đầu 6:00 ngày 1 | Theo prompt M2 / v0.2 |

Chạy (Shift) và né (Space) qua `Player`: tốc độ chạy × buff MOVE_SPEED; né đi bằng `move_and_slide` nên vách, nước, tầng vẫn chặn; quãng lướt đo trên mặt đất (`set_ground_squash`); né hủy combo + vận sức; i-frame qua `Hurtbox.set_invulnerable()`. Hoạt động (chạy/né/đánh/kỹ năng) báo `HungerComponent.exert(Activity.Kind)`. `PlayerSprite`: đi = `walk`, Shift = `run` (tua theo tốc độ thật so với mốc 120 / 240 px/s), né = `run` tua cho vừa 0.2 s (chưa có animation né riêng).

**Ăn uống / dùng item** — `ItemDefinition.consumable: ConsumableEffect` (hunger, health, mana + `buff: BuffDefinition` tùy chọn; số âm = trừ). M3 thêm món chỉ cần item + ConsumableEffect. `ItemUser` (trên Player): đói ≥ 95 thì không ăn món có hồi đói; HP âm không làm chết (còn tối thiểu 1). Item thử: quả mọng (+8 đói, +2 HP), thịt sống (+10 đói, −3 HP), bánh mì (+30, +5 HP), thịt nướng (+40, +15 HP, buff "Ấm bụng" hồi stamina ×1.5 trong 120 s). Cửa sổ túi đồ: **chuột phải** = menu Dùng/Dựng · Trang bị · Tháo · Tách nửa · Vứt (thay cho tách nửa trực tiếp của M1 — đã chốt); **F** (`item_use`) khi rê chuột lên ô hoặc **nhấp đúp** = hành động chính. Ô trang bị mới: **Tay phụ** (`offhand`).

**Ngủ** — `RestSpot` (Interactable, `spot_id`): `Bed` (E → ngủ; `home` = "nhà" tạm trong Glade, chuyển vào nhà ở M5) và `Tent`. `SleepController` (node trong World): `try_sleep` chỉ trong khung giờ → khóa điều khiển, đồng hồ dừng, mờ → `advance(tới 6:00, sleeping=true)` (đói giảm nhịp ngủ) → hồi HP/mana → chỗ ngủ thành **điểm tỉnh dậy / hồi sinh** (`Player.respawn_point = {map_id, kind, id}`) → **tự lưu** (SaveService) → "Ngày N" → sáng lại. Còn thức lúc 2:00 → ngất (hoãn `call_deferred` khỏi signal giờ): M2 tỉnh ở điểm tỉnh dậy lúc 6:00, không hồi, không tự lưu → **M3: tỉnh TẠI CHỖ lúc 6:00**, không hồi, không tự lưu, đói −10 (cộng phần giảm theo nhịp ngủ). Điểm tỉnh dậy không còn (lều đã thu) → giường `home` gần nhất → tại chỗ.

**Lều** — item `tent` (`ItemDefinition.deploy_scene` = `tent.tscn`). Dùng từ túi → `World._deploy_item`: chỉ **một lều** dựng cùng lúc; không trên cầu thang; `PlacementCheck`: đúng tầng (ElevationMap), không phải nước/vách/vực (TerrainLogic), footprint ellipse 14 px không chạm vật cản tầng đó / enemy / vật tương tác khác (rương, giường...). Lều dựng tại chỗ Player đứng, không có thân va chạm. E → menu **Ngủ / Thu lều** (thu: vào túi, điểm tỉnh dậy về nhà). Lưu trong `world_items.deployed`.

**Chết & hồi sinh** — `DeathController` (chỉ map có save; Combat Sandbox giữ "bị hạ gục / R"): HP về 0 → khóa → mờ → **toàn bộ túi đồ** thành một `DeathBag` tại chỗ chết, cùng tầng (đồ đang mặc giữ nguyên, không mất tiền) → hồi sinh ở điểm tỉnh dậy với 50% HP → sáng lại. Chết tiếp khi chưa nhặt túi cũ → túi mới, túi cũ còn (M3: tối đa 5 túi/map, túi thứ 6 → túi cũ nhất biến mất + thông báo; túi rỗng tự xóa khỏi map và save). `DeathBag` (Interactable, E): đồ về túi, phần không vừa rơi xuống đất cạnh đó. `DeathBagMarker` (HUD): dấu trên túi trong màn hình, mũi tên ở mép màn hình + khoảng cách cho túi ngoài màn hình. Lưu trong `world_items.death_bags`.

**HUD** (`CombatHUD`, gộp vào cột trái): "Ngày N · HH:MM · phase" + ô màu phase, HP, thanh Mana (xanh) / Stamina (vàng, đỏ khi kiệt sức), "Đói x / 100" (đỏ nhấp nháy + "cần ăn!" khi < 25), buff đang có; dòng gợi ý phím thứ 3. Bảng "bị hạ gục" tắt ở map có DeathController. (Đã bỏ độ lệch (77, −65) của CombatHUD trong scene Glade — do Godot Editor lưu vào ở commit 619f391 — vì đẩy dòng trên cùng của HUD ra ngoài màn hình.)

**Save v2** — `SCHEMA_VERSION = 2`; `save/save_migrations.gd` đăng ký migration **v1 → v2**: thêm `global.clock = {day 1, minute 360}`, `global.player.survival = {}` (→ chỉ số đầy, chưa có điểm hồi sinh), `world_items.death_bags = []`, `world_items.deployed = []`. `SaveService.capture()` giữ trạng thái global của phiên mà scene hiện tại không có (vd. đồng hồ khi lưu ở test_map). Player lưu thêm `survival: {mana, stamina, hunger, respawn}`; buff không lưu.

```json
"global": {
  "clock": {"version": 1, "day": 5, "minute": 1215.0},
  "player": {"...": "...", "survival": {"mana": 42.5, "stamina": 61.0, "hunger": 37.25,
             "respawn": {"map_id": "glade", "kind": "bed", "id": "glade_home_bed"}}}},
"maps": {"glade": {"world_items": {"version": 2, "collected": ["glade_wood_1"], "dropped": [],
  "death_bags": [{"id": "bag_1760900000_31", "position": [-416.0, 912.0], "tier": 0,
                  "inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 7}]}}],
  "deployed": [{"item_id": "tent", "id": "tent_1760900000", "position": [-416.0, 912.0], "tier": 0}]}}}
```

**Trong Glade:** GameClock, DayNightLighting, SleepController, DeathController (gốc scene); `EntityContainer/Bed` (giường nhà tạm, dưới rương); pickup mới: quả mọng, bánh mì, đèn lồng, lều; rương thêm 2 thịt nướng; VisionLight trên đá rune; UILayer thêm DeathBagMarker, SleepOverlay. Script dựng Glade đã cập nhật (chạy trên bản sao → test đều pass).

**Kiểm thử** (`tests/run_all.gd` chạy tất cả; mọi test kế thừa `tests/test_base.gd` — fail khi có lỗi runtime / push_error ngoài dự kiến): `tests/survival/test_survival.gd` (88 ca, đi qua input thật khi có thể: phím ô kỹ năng, Shift/WASD, Space, I, chuột phải + rê chuột + F trên ô túi đồ, E với giường/lều/túi, F7/F8) — đồng hồ, mana, stamina/chạy/né (quãng 72 px mặt đất, vách chặn, i-frame, kiệt sức), đói, ăn, tầm nhìn đêm + đèn lồng + đá rune, ngủ/ngất, lều (hợp lệ/không, một lều, ngủ, thu, lưu/tải), chết (túi, hồi sinh, đồ mặc, nhặt lại, 2 túi, HUD, lưu/tải), save v2, migration v1 → v2, không còn Energy. `tests/smoke/test_scenes_load.gd` (nạp + chạy 4 scene chính).

**Giới hạn:** chưa có menu hệ thống/pause (đồng hồ chỉ theo SceneTree.paused); đèn lồng chưa tốn dầu; chưa có animation né riêng (dùng run tua nhanh); buff không lưu vào save; ngủ lều không có rủi ro; quái đêm chưa làm (chỉ có signal `darkness_changed`/`phase_changed`); giường "nhà" tạm đặt trong Glade; DeathBag không biến mất theo thời gian; vùng sáng là hình tròn trên mặt đất nên vật cao (cây) bị cắt theo vòng sáng, không có bóng đổ; enemy (HP, vị trí) không lưu; dưới gầm cầu không dựng được lều (điểm thuộc tầng cao).

## 2n. Lượm nhặt, công cụ, chế tạo, nấu ăn, lửa trại & đuốc [Đã triển khai, prototype — TASK M3]

Task M3 của chủ dự án (kéo phần "lượm nhặt & chế tạo" của mốc M4 trong [design/game_design.md](design/game_design.md) mục 6 lên trước; không có trồng trọt, quái đêm, NPC, mở khóa công thức, chế tạo có thời gian chờ, xây nhà). Tận dụng hệ inventory / item / equip / deployable (lều) có sẵn — không viết lại.

```
features/gathering/  resource_node_definition.gd (ResourceNodeDefinition), resource_node.gd (ResourceNode),
                     resource_node_layer.gd (ResourceNodeLayer), data/ (tree, rock, berry_bush, grass .tres),
                     nodes/ (tree_node, rock_node, berry_bush_node, grass_node .tscn — hình placeholder bằng polygon)
features/crafting/   recipe_definition.gd (RecipeDefinition), recipe_book.gd (RecipeBook), crafting.gd (Crafting — logic thuần),
                     crafting_station.gd (CraftingStation), data/ (8 công thức + recipe_book.tres),
                     stations/ workbench.gd/.tscn (bàn chế tạo), campfire.gd/.tscn (Campfire)
features/items/      loot/ loot_entry.gd, loot_table.gd (LootTable), loot_dropper.gd (LootDropper)
                     + item mới: branch, fiber, stone_axe, stone_pickaxe, torch, bandage, campfire, roasted_berry
features/combat/weapons/data/  stone_axe, stone_pickaxe (weapon type `tool`), combo_stone_tool
entities/enemies/loot/  simple_enemy_loot, ranged_enemy_loot, stationary_attacker_loot (.tres)
ui/crafting/         crafting_window.gd/.tscn (CraftingWindow — chế tạo + chế độ Nấu)
```

**Node tài nguyên** — `ResourceNode` (Interactable; con của `ResourceNodeLayer` trong `EntityContainer/Resources`) đọc `ResourceNodeDefinition`. Mỗi lần **E** trừ "sức khai thác" (tay không `HAND_POWER` 1, công cụ `ItemDefinition.harvest_power` 1) vào `toughness`; đủ → tung `yield_table` (LootTable) → **vào thẳng túi**, phần không vừa rơi xuống đất cạnh node. Chọn vào túi (không rơi ra đất) vì vòng lặp khai thác lặp nhiều lần: không phải nhặt từng món, không lạc đồ trong bóng tối, không thêm vật phẩm rơi vào save. Công cụ: `required_tool` (`axe` / `pickaxe`) phải cầm ở **tay chính**; thiếu → lời nhắc "Cần rìu" / "Cần cuốc" và không khai thác. Cây/đá còn cho **nhặt tay** (`hand_table`, `hand_uses` lần mỗi chu kỳ mọc): nhặt cành dưới gốc cây, nhặt đá vụn — để có nguyên liệu làm công cụ đầu tiên. `depletes` = false (bụi mọng): không bị phá, hái xong thì hết quả tới ngày mọc lại. Node bị phá: ẩn hình + tắt thân va chạm, hiện gốc cây / đá vụn. Mọc lại sau `regrow_days` ngày game (lúc 0:00 ngày đó; `ResourceNodeLayer` nghe `GameClock.minute_changed`, kiểm tra cả sau khi tải save).

**Công cụ** — rìu đá / cuốc chim đá là `ItemDefinition` có `weapon` (WeaponDefinition `weapon_type_id = tool`), `tool_type`, `harvest_power`, `max_durability` 40. Trang bị ở **ô Vũ khí (tay chính)** — cùng ô với vũ khí, không thêm ô mới: hệ equip M1 đã có đúng một ô tay chính và vũ khí cầm ở đó thì hiện ra trong combat; công cụ cũng đánh được (combo 1 đòn, damage 5 — kiếm thử 12/14/22). Xung đột: cầm rìu thì không cầm kiếm; đổi qua túi đồ (nhấp đúp / chuột phải). Đề xuất về sau: hotbar đổi nhanh (chưa làm — ngoài phạm vi). Mọi class cầm được công cụ (`ClassDefinition`: `TOOL_TYPE` luôn được phép). **Độ bền** lưu ở `ItemStack.data["durability"]` (field `data` đã có từ M1; thiếu = mới, đầy): mỗi lần khai thác `EquipmentSlots.wear()` trừ 1, về 0 → món biến mất khỏi ô + `item_depleted` → "Rìu đá đã vỡ!". Tooltip + vạch độ bền trên ô (`ItemSlotView`), lời nhắc "Chặt (Độ bền 38/40)". Đuốc: `burn_minutes` 240, nhiên liệu ở `data["fuel"]`, `EquipmentSlots.burn()` theo `GameClock.time_passed` (kể cả khi ngủ), hết → mất ("Đuốc đã cháy hết.").

**Chế tạo** — `RecipeDefinition` (.tres: `id`, `ingredients` {item_id: số}, `result_id`, `result_count`, `station` NONE / WORKBENCH / CAMPFIRE), `RecipeBook` (danh sách, kiểm tra hợp lệ với ItemDatabase). `Crafting` (RefCounted, hàm static, **không chạm UI**): `get_missing`, `get_block_reason`, `craft`, `stations_near` (trạm đang hoạt động, cùng tầng, trong `use_radius` đo trên mặt đất). Thiếu trạm / nguyên liệu → không trừ gì. **Túi đầy: CHẶN** — thành phẩm phải vừa túi sau khi trừ nguyên liệu (mô phỏng trên bản sao Inventory; nguyên liệu dùng hết nhường ô được), không vừa thì không trừ gì, báo "Túi đầy — không còn chỗ cho thành phẩm". Chọn chặn thay vì rơi ra đất để không mất đồ vừa làm trong bóng tối / dưới nước. Chế tạo tức thì.
`CraftingWindow` (phím **C** `craft_toggle`; ô kỹ năng 2 chuyển từ C sang **Z**): liệt kê công thức dùng được ở vị trí hiện tại (tay không + trạm ở gần), nguyên liệu thiếu tô **đỏ**, nút chế tạo khóa kèm lý do; Esc / C đóng; mở thì khóa combat như túi đồ. E ở bàn chế tạo → mở cửa sổ; E ở lửa trại đang cháy → **chế độ Nấu** (chỉ công thức campfire + nút thêm củi); lửa đã tắt → cửa sổ Nấu khóa nấu, còn nút thêm củi để nhóm lại.

**Trạm** — `CraftingStation` (Interactable, group `crafting_stations`, `use_radius`): **Bàn chế tạo** (`workbench.tscn`, 72 px, đặt cạnh giường trong "nhà" tạm ở Glade; có thân va chạm). **Lửa trại** (`Campfire`, 80 px): item `campfire` có `deploy_scene` như lều → `World._deploy_item` dùng chung `PlacementCheck` (đúng tầng, không nước/vách/vực, không chạm vật cản); khác lều: đặt **trước mặt** người chơi 30 px (`ItemDefinition.deploy_offset`, vì có thân va chạm), giới hạn **8 lửa trại/map** (`ItemDefinition.max_per_map`; lều = 1 — thay luật "một lều" cứng của M2 bằng dữ liệu). Cháy 240 phút game lúc dựng, gỗ +120, cành +45, tối đa 720; hết → tắt: ánh sáng tắt, không nấu được, vẫn đứng đó (thân va chạm còn), thêm củi → nhóm lại. Lưu trong `world_items.deployed[*].state = {fuel, lit}`.

**Ánh sáng** — Lửa trại là `VisionLight` bán kính 300 px mặt đất (đèn lồng: 160 + 96 = 256), màu cam. Đuốc ở **Tay phụ** thay đèn lồng: `light_radius` +64 (→ 224, nhỏ hơn đèn lồng). **Ban đêm không đen hẳn** (`DayNightSettings.moonlight` 0.16 = kênh sáng nhất của SunTint lúc tối hẳn, ánh trăng xanh lạnh `moon_tint`; chỉnh trong `day_night_settings.gd/.tres`): thấy bóng cây, địa hình. **Đổi blend của VisionLight từ Add sang Mix** (lý do sửa cấu trúc M2): với Add, vùng 2–3 nguồn sáng chồng nhau cộng vượt 1.0 → cháy trắng (đo bằng render thật: lõi 1 đèn 0.58, 3 đèn chồng nhau 1.0 bão hòa trên nền xám 0.5); Mix kéo màu vùng sáng về `albedo × màu đích` theo alpha của texture (gradient trắng, alpha 1 → 0), nhiều nguồn chồng nhau không vượt màu đích. Màu đích = `ambient` (SunTint hiện tại, DayNightLighting gán mỗi frame).lerp(`color`, darkness) × `energy` → lúc bình minh/hoàng hôn màu đích ≈ ambient nên bật/tắt không giật. Chi phí vẽ như cũ (đo cùng máy: Add 4.3 FPS vs Mix 4.2 FPS ở llvmpipe). Đá rune `energy` 1.1 → 1.0 (Mix không cần bù).

**Nguồn thịt** — enemy M2 chưa rơi gì. Thêm `LootDropper` (con của enemy, nghe `HealthComponent.died`, thả từng stack xuống đất cạnh xác qua `ItemPickupLayer` cùng tầng; map không có layer — Combat Sandbox — không rơi) + `LootTable` data-driven ở `entities/enemies/loot/`. `LootTable`/`LootEntry` (`item_id`, `min_count`, `max_count`, `chance`) dùng chung cho node tài nguyên.

**Hệ số mặc định**

| Mục | Mặc định | Lý do |
|---|---|---|
| Stamina chạy | 12/s (M2: 20/s) | Theo task; chạy liên tục ~8.3 s |
| Ánh trăng `moonlight` | 0.16 (≈ 13 % độ sáng cảm nhận) | Trong khoảng 12–18 % của task; thấy bóng cây + địa hình, không rõ chi tiết |
| Đói = 0 | −6 % HP tối đa / giờ game | Công thức: thời gian chết = 100 / 6 giờ game = 16.7 giờ game = 1000 phút game; 1 ngày (1440 phút game) = 1200 s thực → 1000 × 1200 / 1440 = **833 s ≈ 13.9 phút thực** (trong 12–15 phút), không phụ thuộc max HP |
| Ngủ | giường 100 % HP + 100 % mana; lều 70 % HP + 100 % mana; hồi sinh 50 % | Theo task |
| Ngất | tỉnh tại chỗ 6:00, không hồi HP, không tự lưu, đói −10 | Theo task |
| Túi đồ khi chết | tối đa 5/map; túi rỗng tự xóa | Theo task |
| Tay không / công cụ | sức khai thác 1; độ bền rìu, cuốc 40 | Một cây (toughness 4) tốn 4 độ bền → 10 cây / công cụ |
| Công cụ làm vũ khí | 1 đòn, damage 5, tầm 26, knockback 60 | Thấp hơn hẳn kiếm thử (12/14/22) |
| Đuốc | cháy 240 phút game (4 giờ ≈ 3.3 phút thực), +64 px | Đủ đi một đoạn đêm; nhỏ hơn đèn lồng (+96) |
| Lửa trại | 240 phút khi dựng, gỗ +120, cành +45, tối đa 720; bán kính 300; dùng trong 80 px; 8 / map | Một bộ củi cháy qua nửa đêm; thêm 4 gỗ là tới sáng |
| Bàn chế tạo | dùng trong 72 px | Đứng cạnh bàn |

**Bảng công thức**

| Công thức | Nguyên liệu | Kết quả | Trạm |
|---|---|---|---|
| Rìu đá | 2 cành, 2 đá, 3 sợi | 1 | tay |
| Cuốc chim đá | 2 cành, 3 đá, 3 sợi | 1 | tay |
| Đuốc | 1 cành, 1 sợi | 1 | tay |
| Băng gạc (+12 HP, dùng được cả khi no) | 4 sợi | 1 | tay |
| Lửa trại | 3 gỗ, 2 cành, 2 đá | 1 | tay |
| Lều | 4 gỗ, 8 sợi, 4 cành | 1 | bàn chế tạo |
| Thịt nướng (+40 đói, +15 HP, buff Ấm bụng) | 1 thịt sống | 1 | lửa trại |
| Quả mọng nướng (+20 đói, +5 HP) | 2 quả mọng | 1 | lửa trại |

**Bảng rơi đồ**

| Nguồn | Cách | Rơi | Độ bền khai thác | Mọc lại |
|---|---|---|---|---|
| Cây sồi | rìu | 3–4 gỗ + 1–2 cành | 4 lần | 3 ngày |
| Cây sồi | tay (nhặt cành, 2 lần/chu kỳ) | 1–2 cành | 1 | cùng chu kỳ |
| Tảng đá | cuốc chim | 3–5 đá | 4 lần | 4 ngày |
| Tảng đá | tay (nhặt đá vụn, 2 lần/chu kỳ) | 1 đá | 1 | cùng chu kỳ |
| Bụi mọng (không bị phá) | tay | 2–3 quả mọng | 1 | 2 ngày |
| Bụi cỏ | tay | 2–3 sợi | 1 | 1 ngày |
| Melee Chaser (simple_enemy) | chết | 1–2 thịt sống (100 %) | — | — |
| Ranged enemy | chết | 1 thịt sống (60 %) | — | — |
| Stationary Attacker | chết | 2 thịt sống (100 %) | — | — |

**Save v3** — `SCHEMA_VERSION = 3`; migration **v2 → v3** thật (`SaveMigrations.migrate_2_to_3`): thêm `maps.<id>.resource_nodes = {version 1, nodes: {}}` (mọi node đầy), `world_items.version` → 3, `deployed[*].state = {}` (lều không có trạng thái riêng). Độ bền công cụ / nhiên liệu đuốc ở `ItemStack.data` — save v2 chưa có công cụ nên túi/trang bị/rương giữ nguyên (thiếu field = đầy). Chuỗi v1 → v2 → v3 chạy tự động; test tải save v1 (M1) và v2 (M2) đều thành công và lưu lại thành v3.

```json
"maps": {"glade": {
  "resource_nodes": {"version": 1, "nodes": {
    "glade_tree_3": {"depleted": true, "regrow_day": 4, "progress_left": 4, "hand_left": 2}}},
  "world_items": {"version": 3, "deployed": [
    {"item_id": "campfire", "id": "campfire_1760900000_0042", "position": [-416.0, 912.0], "tier": 0,
     "state": {"fuel": 185.5, "lit": true}}]}}},
"global": {"player": {"equipment": {"version": 1, "slots": {"weapon": {"id": "stone_axe", "count": 1, "data": {"durability": 36}}}}}}
```

**Trong Glade:** `EntityContainer/Workbench` (cạnh giường nhà tạm), `EntityContainer/Resources` (ResourceNodeLayer: 4 cây, 3 đá, 3 bụi mọng, 5 bụi cỏ quanh khu nhà / bờ suối), `UILayer/CraftingWindow`; World export `recipe_book`, `crafting_window`, `resource_layer`. Script dựng Glade (`tools/glade/build_glade_prototype.gd`) đã thêm các node này và giờ instance scene con bằng `GEN_EDIT_STATE_INSTANCE` (trước đó ghi đè cứng mọi thuộc tính của instance — đó là nguồn gốc độ lệch CombatHUD); chạy trên bản sao → toàn bộ test pass, scene commit vẫn là bản chỉnh tay (khác nhau chỉ ở id/thứ tự).

**Kiểm thử** — `tests/crafting/test_crafting.gd` (40 ca, logic thuần: dữ liệu hợp lệ, trạm, thiếu nguyên liệu không trừ đồ, túi đầy chặn / nguyên liệu nhường ô, độ bền vỡ đúng lần 40, đuốc cháy hết, bảng rơi đồ, migration v2 → v3). `tests/gathering/test_gathering.gd` (92 ca, qua input thật: E, C, Esc, WASD, chuột trên cửa sổ): **vòng lặp đầy đủ** nhổ cỏ → nhặt cành → nhặt đá vụn → chế rìu (UI) → trang bị → chặt cây → chế + dựng lửa trại → giết enemy rơi thịt → nấu → ăn → đói tăng đúng; thiếu công cụ / sai công cụ không khai thác; rìu vỡ đúng lần cuối; thiếu nguyên liệu đỏ + nút khóa + không trừ; túi đầy chặn; bàn chế tạo; node mọc lại đúng ngày kể cả sau save/load; lửa trại hết giờ → ánh sáng tắt, nhóm lại, chặn đường, chỗ dựng sai, giới hạn/map; chồng sáng không cháy trắng (Mix); đuốc; 5 túi đồ + túi rỗng; CombatHUD không có thuộc tính offset/anchor ghi đè trong scene Glade + nằm trong màn hình; lời nhắc [E] không chạm dòng gợi ý phím; tải save v1, v2.
**Hiệu năng** (đêm + 5 lửa trại + đuốc): máy dev (AMD Radeon tích hợp, vsync tắt, bản Add trước khi sửa) 79 FPS. Môi trường CI không có GPU (Mesa llvmpipe, render bằng CPU, 1152×648) chỉ để so tương đối: ngày 16.7, đêm 9.3, đêm + 5 lửa + đuốc 4.2 FPS; Add và Mix bằng nhau. Cần đo lại trên máy dev sau khi đổi Mix.

**Giới hạn:** hình node tài nguyên, bàn chế tạo, lửa trại là polygon placeholder; chưa có animation khai thác (mỗi lần E là một nhát); chế tạo tức thì; công cụ chỉ có cấp đá, chưa có liềm; đổi vũ khí ↔ công cụ phải qua túi đồ (chưa có hotbar); bàn chế tạo di động **không làm** (theo task); lửa trại không lan cháy, không gây sát thương; vùng sáng vẫn là hình tròn trên mặt đất, không có bóng đổ; đuốc không thả xuống đất / cắm được; enemy rơi thịt theo bảng cố định, chưa có thú săn (M4); node tài nguyên chỉ đặt tay trong Glade (chưa sinh ngẫu nhiên, chưa có map phụ); FPS sau khi đổi Mix chưa đo trên máy có GPU.

## 3. Quy ước đặt tên [Đã quyết định]

Theo [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- File và thư mục: `snake_case` (`main.tscn`, `health_component.gd`).
- `class_name`, tên node: `PascalCase`.
- Hàm, biến, signal: `snake_case`; signal dùng thì quá khứ (`died`, `health_changed`).
- Hằng số, enum value: `CONSTANT_CASE`.
- Thành viên private: tiền tố `_`.

## 4. Static typing [Đã quyết định]

Mọi script mới phải khai báo kiểu cho biến, tham số và giá trị trả về. `project.godot` bật cảnh báo:

- `debug/gdscript/warnings/untyped_declaration = Warn`
- `debug/gdscript/warnings/inference_on_variant = Warn`

Code mới không được để lại các cảnh báo này.

## 5. Entity: Composition + base class mỏng [Đã quyết định, chưa triển khai]

- Entity (player, NPC, enemy) là một scene ghép từ các **component node** (vd. máu, di chuyển, hitbox), mỗi component một trách nhiệm.
- Có thể có một base class mỏng chung cho entity, chỉ chứa phần thật sự dùng chung. Không xây cây kế thừa sâu.
- Hành vi mới được thêm bằng cách ghép component, không bằng cách kế thừa thêm tầng.

## 6. Giao tiếp giữa module: Public API và Signals [Đã quyết định]

- Mỗi module công khai một tập hàm/thuộc tính rõ ràng (public API). Thành phần nội bộ đặt tiền tố `_` và không bị module khác truy cập.
- Hướng "xuống" (cha → con, người dùng → module): gọi hàm public.
- Hướng "lên" hoặc thông báo sự kiện (con → cha, module → bất kỳ ai quan tâm): phát **signal**.
- Không truy cập node của module khác bằng đường dẫn cứng (`get_node("../../...")`).

## 7. Phân tách logic, dữ liệu và UI [Đã quyết định]

- **Gameplay logic** không tham chiếu trực tiếp đến node UI.
- **UI** chỉ đọc trạng thái qua public API và lắng nghe signal; UI không chứa luật gameplay.
- **Dữ liệu thiết kế** (chỉ số, cấu hình) nằm trong Resource, không hard-code trong script.

## 8. Dữ liệu thiết kế và runtime state [Đã quyết định]

| | Dữ liệu thiết kế | Runtime state |
|---|---|---|
| Ví dụ | Máu tối đa của một loại enemy | Máu hiện tại của một enemy cụ thể |
| Lưu ở | Custom Resource (`.tres`) | Biến trong node/component |
| Thay đổi khi chơi | Không | Có |
| Được lưu vào save | Không (chỉ tham chiếu ID) | Có |

Resource dùng chung giữa nhiều instance **không được** bị sửa trong lúc chạy. Nếu cần giá trị riêng, sao chép sang runtime state hoặc `duplicate()` có chủ đích.

## 9. Autoload [Đã quyết định]

- Có đúng **một** Autoload: `SaveService` (`save/save_service.gd`, TASK M1, người dùng đã đồng ý) — xem 2l. Không thêm Autoload khác khi chưa được đồng ý. Item database **không** phải Autoload.
- Chỉ thêm Autoload khi có nhu cầu thực sự mang tính toàn cục (vd. dịch vụ save, điều phối chuyển scene) và phải được người dùng đồng ý.
- Không dùng Autoload làm "manager" chứa logic gameplay hoặc làm kho trạng thái tùy tiện.

## 10. Save / Load [Đã triển khai — TASK M1, chi tiết 2l; schema 2 + migration v1 → v2 ở 2m; schema 3 + migration v2 → v3 ở 2n]

lưu **runtime state** ra file JSON trong `user://`, logic nằm ở `save/`. File save chỉ chứa dữ liệu thuần (số, chuỗi, ID), tham chiếu dữ liệu thiết kế bằng ID/đường dẫn, không serialize trực tiếp Resource hay node. Định dạng có trường phiên bản (`schema_version`) để hỗ trợ migrate. Hệ thống mới muốn được lưu: thêm node vào group `saveable` + 3 hàm `get_save_id` / `save_state` / `load_state` (ID ổn định), không sửa SaveService.

## 11. Những gì chưa được quyết định

Các mục sau sẽ quyết định trong task riêng, không tự chọn trước:

- Độ phân giải pixel-art gốc, viewport scale, chế độ stretch cuối cùng. (Môi trường mới theo hướng hand-painted độ phân giải cao — 2k. Đã có: cửa sổ mặc định 1920×1080, viewport gốc vẫn 1152×648 — mục 2k; độ phân giải thiết kế cuối cùng vẫn chưa chốt.)
- Độ phân giải thiết kế / stretch mode cuối cùng (ảnh hưởng zoom và pixel-perfect).
- Điều khiển nhân vật chính thức (gamepad, remapping). Input Map di chuyển, chạy, né đã có (2c, 2m).
- Luồng chuyển scene / menu.
- Công cụ kiểm thử.
