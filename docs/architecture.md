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
| `features/` | Module gameplay (mỗi tính năng một thư mục con, vd. `features/combat/`) | Đã triển khai (`interaction/`, `combat/`, `character/`, `skills/`, `classes/`) |
| `entities/` | Player, NPC, enemy (scene ghép từ component) | Đã triển khai (`player/`, `enemies/` — placeholder) |
| `world/` | Bản đồ, môi trường, camera | Đã triển khai (`world.tscn`, `world.gd`, `maps/test_map/`, `camera/`, `sandbox/`, `environment/`, `environment_prototype/` — 2k) |
| `ui/` | Thành phần giao diện | Đã triển khai (`interaction/`, `combat/`, `skills/`, `progression/`, `debug/`, `common/`) |
| `data/` | Dữ liệu game dùng chung (`.tres` Resource) | Chưa triển khai |
| `assets/` | Tài nguyên dùng chung (sprite, âm thanh, font) | Chưa triển khai |
| `save/` | Logic lưu / tải game | Chưa triển khai |
| `tests/` | Kiểm thử | Chưa triển khai |
| `addons/` | Plugin bên thứ ba (chỉ khi thật sự cần) | Chưa triển khai |
| `tools/` | Công cụ phát triển chạy ngoài game (có `.gdignore`), vd. sinh placeholder art | Đã triển khai (`placeholder_art/`, 2k) |

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
    └── ProgressionPanel        — bảng Class/Progression thử nghiệm (2i)
```

- **Main Scene** là entry point: màn hình khởi động tạm và chuyển vào World. Không giữ trạng thái game.
- **World Scene** là gốc của môi trường game. Không phụ thuộc Main Scene, mở và chạy độc lập bằng F6.
- `world.gd` cung cấp public API trả về các container (`get_map_container()`, `get_entity_container()`, ...) và `get_map_rect()`; nối camera với target/map và InteractionDetector với UI lúc `_ready` (qua các export trong `world.tscn`). Không chứa logic gameplay.
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

## 2c. Player [Đã triển khai, placeholder]

```
entities/player/player.tscn
Player (CharacterBody2D, motion_mode = Floating) ── player.gd
├── Visual (Node2D)
│   ├── Shadow (Polygon2D)        — bóng ellipse tại chân
│   ├── Body (Polygon2D)          — khối xanh 16×26 phía trên chân
│   └── FacingPivot (Node2D)      — xoay theo hướng di chuyển cuối
│       └── Marker (Polygon2D)    — tam giác vàng chỉ hướng trước mặt
├── CollisionShape2D              — CircleShape2D r=6, tâm (0,-6): chạm tới chân
└── InteractionDetector, HealthComponent, Hurtbox, HitFlash, WeaponEquipment, BasicAttackController, DebugWeaponSwitcher, SkillLoadout, SkillCastingController, PassiveController, ClassManager, CharacterLevel — xem 2e–2i
```

- **Origin = chân nhân vật**, nên Y-sort trong `EntityContainer` dựa trên điểm tiếp xúc mặt đất. Visual vẽ phía trên origin. Không dùng Z-index.
- **Input Map** (`project.godot`): `move_up` W/↑, `move_down` S/↓, `move_left` A/←, `move_right` D/→. Dùng physical keycode (đúng vị trí WASD trên mọi layout bàn phím). Script chỉ đọc action, không kiểm tra phím vật lý.
- **Di chuyển:** `_physics_process` → `Input.get_vector()` → `velocity = direction * move_speed` → `move_and_slide()`. Liên tục, 8 hướng, chéo được chuẩn hóa (|v| ≤ `move_speed`), thả phím thì dừng ngay; không tăng tốc/quán tính.
- `move_speed` (`@export`, mặc định **160 px/s**) — giá trị thử nghiệm.
- **Spawn:** đặt trực tiếp trong `world.tscn` tại (480, 320), giữa quảng trường đá. Chưa có SpawnManager/checkpoint.
- Placeholder: toàn bộ visual, kích thước collision, tốc độ, vị trí spawn.
- `player.gd` chỉ đọc input (`basic_attack` → `BasicAttackController.request_attack()`), chặn điều khiển khi chết và cung cấp `is_dead()`, `reset_state()`, `get_aim_direction(world_point)`, `set_combat_input_blocked(bool)` (UI đang mở: bỏ qua đánh thường/kỹ năng, hủy ngắm/vận sức/combo; di chuyển vẫn được). Tốc độ = `move_speed` × hệ số passive. Logic HP/đòn đánh/class nằm trong component.

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

- Stretch `canvas_items` + `expand` (từ TASK 01) giữ nguyên. Khi cửa sổ khác 1152×648 theo tỉ lệ không nguyên (vd. 1920×1080 = 1.67×), một pixel nghệ thuật không còn là số nguyên pixel màn hình → kích thước pixel có thể không đều. Sẽ xử lý khi chốt độ phân giải thiết kế.
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
- Vùng tấn công là hình chữ nhật; chưa có animation chính thức.
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

**Phím debug** (không phải phím chính thức): `1` Sword, `2` Dagger, `3` Heavy (`debug_weapon_1..3`, xử lý bởi `DebugWeaponSwitcher`; xóa node này khi có quy trình trang bị chính thức).

**Tạo vũ khí mới:** FileSystem → New Resource → `ComboStepDefinition`/`ComboDefinition` (hoặc nhân bản `combo_test_*.tres`) → chỉnh các bước; New Resource → `WeaponDefinition`, đặt `weapon_id`, `weapon_type_id`, gán `combo`. Gán vào `WeaponEquipment.starting_weapon` hoặc thêm vào mảng `DebugWeaponSwitcher.weapons`. Không cần sửa code.

Giới hạn: hitbox mỗi bước là hình chữ nhật (chưa có arc thật); chưa có animation; enemy vẫn dùng MeleeAttack đơn (không combo). Luật class ↔ vũ khí: xem 2i.

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

## 2k. Environment Visual Foundation & Prototype [Đã triển khai, prototype — TASK VISUAL 01]

Định hướng đồ họa môi trường: **High-Resolution Hand-Painted 2D** (thay cho pixel art ở môi trường mới). Quy ước art: [visual/environment-style-guide.md](visual/environment-style-guide.md). Art hiện tại là **placeholder sinh bằng code** (`tools/placeholder_art/`), chưa phải production art.

```
world/environment/                      — nền tảng tái sử dụng (không gắn với một map)
├── elevation/  elevation_map.gd (ElevationMap), elevated_terrain.gd (@tool ElevatedTerrain),
│               elevated_deck.gd (ElevatedDeck), elevation_connector.gd (ElevationConnector), elevation_agent.gd (ElevationAgent)
├── props/      environment_prop.gd, occlusion_fader.gd + 15 scene: tree_oak_a/b, tree_pine, bush_a/b, fern,
│               rock_large/small/flat, ruin_pillar(_broken), ruin_arch, ruin_wall, ruin_blocks, rune_stone
├── terrain/    terrain_ground.gdshader, terrain_path.gdshader, decal_scatter.gd (@tool DecalScatter),
│               terrain_logic.gd (TerrainLogic) + terrain_logic_tileset.tres, material ground_grass(_upper)/path_dirt/shore_mud.tres
├── water/      stream.gd (Stream), footbridge.gd (Footbridge), water_surface/waterfall.gdshader + material
├── atmosphere/ ambient_drift.gd (AmbientDrift: sương, tia nắng, lá foreground)
└── art/        PNG placeholder (ground, cliff, props, structures, decals, fx, scenery, terrain)
world/environment_prototype/environment_prototype.tscn — World thứ ba (script world.gd), khu "Glade" 64×44 ô
ui/debug/environment_debug_hud.gd/.tscn — tầng hiện tại, loại địa hình (lưới logic), zoom, nút bật lưới Terrain Logic
tools/placeholder_art/ (có .gdignore) — script sinh lại placeholder art
```

**Truy cập:** Main Scene → nút **Environment Prototype (Visual 01)**, hoặc mở `environment_prototype.tscn` + F6.

**Cây scene (rút gọn):** `Environment` (SunTint CanvasModulate, ScenicBackground Parallax2D z −100, Atmosphere z 40, Foreground z 50) → `MapContainer/GladeMap` (z −20: TerrainLogic ẩn, MapBounds, NorthLedge, BaseGround, Transitions, Paths, Stream, Footbridge, bóng AO chân vách, Details/DecalScatter, LedgeLip) → `EntityContainer` (Y-sort: `Elevation` [ElevationMap: Plateau, Outcrop, StoneBridge, CliffStairs, Waterfall, UpperGroundDetail], `Props`, Player + ElevationAgent, NoticeBoard, TrainingDummy, SimpleEnemy + ElevationAgent) → EffectContainer, CameraContainer (GameCamera zoom 1–3×, bước 0.25), UILayer (layer 2).

**Terrain logic vs visual:** tile logic 32×32 giữ nguyên; `TerrainLogic` (ẩn) phân loại grass/dirt/water/cliff/high/void và là nguồn kích thước map cho MapBounds/camera. Hình ảnh mặt đất là texture lớn theo tọa độ world + overlay Line2D/decal, không khớp 1:1 với tile. Collision lấy từ hình học logic (outline, đường tâm suối), không từ texture.

**Elevation (Discrete Tiers):**

- Physics layer 7 `terrain_tier_0`, 8 `terrain_tier_1` (layer = 7 + tier). `ElevationMap._build()` lúc `_ready`: tầng 1 → tường = đường bao hợp (mặt trên các `ElevatedTerrain` tầng 1 ∪ `ElevatedDeck` ∪ hành lang connector); tầng 0 → tường = đường bao hợp các khối (mặt trên ∪ vách đùn xuống 64 px) trừ hành lang connector. Tường là `CollisionPolygon2D` dạng SEGMENTS (chặn hai phía).
- `ElevationAgent` (con của CharacterBody2D): `collision_mask` = mask gốc + bit tầng hiện tại; `z_index = tier × 10`. Tầng chỉ đổi qua `ElevationConnector`: trong hành lang, agent ở trạng thái chuyển tầng (chỉ layer `world` + lan can hai bên chặn, vẽ ở tầng cao); rời hành lang về phía −Y local → upper_tier, ngược lại lower_tier. Tầng ban đầu / sau reset: `ElevationMap.get_tier_at()` (hoặc `initial_tier`). Signal `tier_changed(tier, transitioning)`. Map không có ElevationMap: agent không làm gì.
- **Rendering:** khối địa hình cao nằm trong Y-sort tầng 0 (mỗi đoạn vách neo tại chân vách → entity tầng 0 đứng trước vách vẽ đè lên vách, đứng sau bị che); occupant tầng 1 có z 10 nên luôn vẽ trên nội dung tầng 0 — không phụ thuộc hoàn toàn vào Y-sort khi hai mặt sàn chồng nhau (cầu đá: Player tầng 1 đi trên mặt cầu, Player tầng 0 đi dưới gầm, cầu mờ đi nhờ OcclusionFader).
- Prop có `elevation_tier` → z_index và physics layer của `Collision`.

**Object môi trường:** `EnvironmentProp` (origin = chân): Shadow (z −1), Visual (Sprite2D scale 0.5), Collision (StaticBody2D chỉ ở gốc/thân), OcclusionFader (vật cao: làm mờ khi thân layer `player` đứng sau và không ở tầng cao hơn).

**Nước:** `Stream` sinh collision (layer tầng 0) từ Line2D `Water` (kể cả width_curve, 78% bề rộng), khoét các `crossings` (Footbridge). Shader mặt nước: sâu/nông theo bề ngang, gợn trôi theo `flow_direction`, bọt mép. Thác nước: Polygon2D + shader đơn giản (hoàn thiện ở VISUAL 03). Không có bơi/lặn/vật lý nước.

**Kiểm thử đã chạy (headless, giả lập input):** lên/xuống cầu thang, vách chặn tầng 0 và mép plateau chặn tầng 1, qua cầu đá sang mỏm đá, đi dưới gầm cầu ở tầng 0, nước chặn, đi qua cầu gỗ, thân cây chặn, mép vực bắc, mép map — 13/13 đạt. Render: 60 FPS (vsync), ~95 draw call, ~24 MB texture ở zoom 1× (máy dev).

**Giới hạn:** enemy không pathfinding nên kẹt ở chân vách khi đuổi Player lên tầng cao; Hitbox/Hurtbox/đạn chưa lọc theo tầng (đòn đánh có thể trúng mục tiêu khác tầng nếu chồng hình); đạn (raycast layer `world`) không bị vách chặn; vật cao tầng 0 có sprite chồng lên mặt đi được của tầng 1 sẽ vẽ sai thứ tự (quy tắc đặt object, xem style guide); mỗi khối địa hình cần cạnh trước "đơn điệu"; `get_tier_at()` dưới gầm cầu trả tầng cao (chỉ dùng khi spawn/reset); skill indicator (`top_level`) vẽ ở z 0.

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
| Được lưu vào save | Không (chỉ tham chiếu ID/đường dẫn) | Có |

Resource dùng chung giữa nhiều instance **không được** bị sửa trong lúc chạy. Nếu cần giá trị riêng, sao chép sang runtime state hoặc `duplicate()` có chủ đích.

## 9. Autoload [Đã quyết định]

- Hiện tại **không có Autoload nào**.
- Chỉ thêm Autoload khi có nhu cầu thực sự mang tính toàn cục (vd. dịch vụ save, điều phối chuyển scene) và phải được người dùng đồng ý.
- Không dùng Autoload làm "manager" chứa logic gameplay hoặc làm kho trạng thái tùy tiện.

## 10. Save / Load [Chưa triển khai]

Định hướng: lưu **runtime state** ra file JSON trong `user://`, logic nằm ở `save/`. File save chỉ chứa dữ liệu thuần (số, chuỗi, ID), tham chiếu dữ liệu thiết kế bằng ID/đường dẫn, không serialize trực tiếp Resource hay node. Định dạng có trường phiên bản để hỗ trợ migrate.

## 11. Những gì chưa được quyết định

Các mục sau sẽ quyết định trong task riêng, không tự chọn trước:

- Độ phân giải pixel-art gốc, viewport scale, chế độ stretch cuối cùng. (Môi trường mới theo hướng hand-painted độ phân giải cao — 2k; độ phân giải thiết kế cuối cùng vẫn chưa chốt.)
- Độ phân giải thiết kế / stretch mode cuối cùng (ảnh hưởng zoom và pixel-perfect).
- Điều khiển nhân vật chính thức (animation, dodge, gamepad, remapping). Input Map di chuyển cơ bản đã có (mục 2c).
- Luồng chuyển scene / menu.
- Công cụ kiểm thử.
