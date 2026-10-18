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
| `features/` | Module gameplay (mỗi tính năng một thư mục con, vd. `features/combat/`) | Đã triển khai (`interaction/`, `combat/`, `character/`) |
| `entities/` | Player, NPC, enemy (scene ghép từ component) | Đã triển khai (`player/`, `enemies/` — placeholder) |
| `world/` | Bản đồ, môi trường, camera | Đã triển khai (`world.tscn`, `world.gd`, `maps/test_map/`, `camera/`) |
| `ui/` | Thành phần giao diện | Đã triển khai (`interaction/`, `combat/`) |
| `data/` | Dữ liệu game dùng chung (`.tres` Resource) | Chưa triển khai |
| `assets/` | Tài nguyên dùng chung (sprite, âm thanh, font) | Chưa triển khai |
| `save/` | Logic lưu / tải game | Chưa triển khai |
| `tests/` | Kiểm thử | Chưa triển khai |
| `addons/` | Plugin bên thứ ba (chỉ khi thật sự cần) | Chưa triển khai |

Thư mục chỉ được tạo khi có nội dung thực tế. Không tạo thư mục, script hoặc class rỗng để "giữ chỗ".

## 2a. Scene hiện tại [Đã triển khai]

```
app/main.tscn  (Main Scene, entry point)
Main (Control) ── main.gd
├── Background (ColorRect)
└── Center (CenterContainer)
    └── Layout (VBoxContainer)
        ├── StatusLabel (Label)
        └── EnterButton (Button "Vào game")
            └─ nhấn → SceneTree.change_scene_to_file("res://world/world.tscn")

world/world.tscn  (World Scene, mở độc lập được)
World (Node2D) ── world.gd
├── Environment (Node2D)        — nền, trang trí, hiệu ứng môi trường
├── MapContainer (Node2D)       — bản đồ / TileMapLayer
│   └── TestMap (instance world/maps/test_map/test_map.tscn)
├── EntityContainer (Node2D, y_sort_enabled) — player, NPC, enemy
│   ├── Player (instance entities/player/player.tscn, spawn (480, 320))
│   ├── NoticeBoard (400, 256), TestChest (528, 392), TestCrystal (576, 392) — vật thể tương tác thử nghiệm
│   └── TrainingDummy (656, 240), SimpleEnemy (300, 420) — mục tiêu combat thử nghiệm
├── CameraContainer (Node2D)    — camera
│   └── GameCamera (instance world/camera/game_camera.tscn)
└── UILayer (CanvasLayer)     — UI cố định trên màn hình
    ├── CombatHUD
    ├── InteractionPrompt
    └── InteractionFeedback
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

Chưa triển khai: NPC, enemy chính thức.

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
└── InteractionDetector, HealthComponent, Hurtbox, HitFlash, WeaponEquipment, BasicAttackController, DebugWeaponSwitcher — xem 2e, 2f, 2g
```

- **Origin = chân nhân vật**, nên Y-sort trong `EntityContainer` dựa trên điểm tiếp xúc mặt đất. Visual vẽ phía trên origin. Không dùng Z-index.
- **Input Map** (`project.godot`): `move_up` W/↑, `move_down` S/↓, `move_left` A/←, `move_right` D/→. Dùng physical keycode (đúng vị trí WASD trên mọi layout bàn phím). Script chỉ đọc action, không kiểm tra phím vật lý.
- **Di chuyển:** `_physics_process` → `Input.get_vector()` → `velocity = direction * move_speed` → `move_and_slide()`. Liên tục, 8 hướng, chéo được chuẩn hóa (|v| ≤ `move_speed`), thả phím thì dừng ngay; không tăng tốc/quán tính.
- `move_speed` (`@export`, mặc định **160 px/s**) — giá trị thử nghiệm.
- **Spawn:** đặt trực tiếp trong `world.tscn` tại (480, 320), giữa quảng trường đá. Chưa có SpawnManager/checkpoint.
- Placeholder: toàn bộ visual, kích thước collision, tốc độ, vị trí spawn.
- `player.gd` chỉ đọc input (`basic_attack` → `BasicAttackController.request_attack()`), chặn điều khiển khi chết và cung cấp `is_dead()`, `reset_state()`, `get_aim_direction(world_point)`. Logic HP/đòn đánh nằm trong component.

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
- **Zoom:** chỉ dùng mức nguyên. `@export default_zoom = 2`, `min_zoom = 1`, `max_zoom = 4`. Input Map: `camera_zoom_in` = lăn chuột lên, `camera_zoom_out` = lăn chuột xuống; mỗi nấc ±1, đổi tức thì (không tween).
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
├── melee_attack.gd/.tscn — class_name MeleeAttack (Node2D): đòn đơn dùng cho enemy (Player dùng BasicAttackController, xem 2g)
├── knockback_component.gd — class_name KnockbackComponent (Node): đẩy lùi cho CharacterBody2D
└── hit_flash.gd          — class_name HitFlash (Node): nháy màu / tô xám theo HP (chỉ visual)
entities/enemies/
├── training_dummy/       — Node2D đứng yên, HP 60, không AI
└── simple_enemy/         — CharacterBody2D, HP 40, AI đơn giản (IDLE / CHASE / ATTACK / DEAD)
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

**MeleeAttack** (enemy; export, mọi giá trị là placeholder):

| | damage | attack_range | attack_width | windup | duration | cooldown | target_layers |
|---|---|---|---|---|---|---|---|
| SimpleEnemy | 10 | 26 | 20 | 0.35 s | 0.15 s | 1.0 s | 5 `player_hurtbox` |

API: `attack(direction) -> bool`, `can_attack()`, `is_attacking()`, `cancel()`, `get_hitbox()`; signal `attack_started(direction)`, `attack_finished`. Chỉ xoay node MeleeAttack (Hitbox + visual), không xoay thực thể. Đang đánh/nghỉ thì bỏ qua. Không đánh khi `health` của chủ thể đã chết.

**SimpleEnemy** — export `target` (World gán Player), `move_speed` 70, `detection_range` 150, `attack_trigger_ratio` 0.8 × `MeleeAttack.attack_range`. Ngoài tầm: đứng yên; trong tầm: đi thẳng tới target (`move_and_slide`, mask `world`, có thể kẹt sau vật cản, không pathfinding); đủ gần: đứng lại và đánh. Chỉ đọc vị trí và `is_dead()` của target (nếu có), không đọc HP. Chết: dừng AI, hủy đòn. Thân enemy layer 4, mask 1; Player và enemy không chặn nhau.

**Chết / reset (thử nghiệm):**

- Player chết: không di chuyển/tấn công, `InteractionDetector.set_enabled(false)`, tô xám, HUD hiện "Bạn đã bị hạ gục".
- Phím **R** (`debug_reset`, không phải phím chính thức): `World.reset_test_state()` gọi `reset_state()` trên mọi node group `test_resettable` (Player, dummy, enemy) rồi `camera.set_target()` để camera nhảy ngay về Player. Player về spawn, HP đầy, vận tốc 0, hủy đòn; enemy về spawn. Không reload scene.

**HUD / feedback:** `World._ready()` gọi `CombatHUD.bind_player_health()` và nối `hit_received` của mọi Hurtbox trong World tới `CombatHUD.show_damage()` (số sát thương + "Hạ gục!"). DamageNumbers chuyển vị trí world → màn hình bằng `get_canvas_transform()` mỗi frame nên đúng ở mọi mức zoom. UI không tính damage, không sửa HP.

**Thêm một mục tiêu có HP:** thêm `HealthComponent` + `Hurtbox` (Area2D, `layer` = 5 hoặc 6 theo phe, `mask = 0`, `monitoring = false`, gán `health`, thêm CollisionShape2D); tùy chọn `HitFlash`, `WorldHealthBar`. Muốn tấn công: instance `melee_attack.tscn`, đặt `target_layers` = layer Hurtbox phe đối địch, gán `health`. Muốn reset bằng R: thêm vào group `test_resettable` và viết `reset_state()`. Đặt trong `EntityContainer`.

**Kiểm tra trong game:** F5 → Vào game. Chuột trái để chém về phía con trỏ; dummy (bù nhìn rơm, bên phải quảng trường) và enemy đỏ (dưới trái) có thanh HP. Đến gần enemy để nó đuổi và đánh. **R** để reset.

Giới hạn prototype:

- Hurtbox chỉ được nối vào HUD lúc `World._ready()`; thực thể sinh ra sau này cần được nối thêm.
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

**WeaponEquipment** — export `starting_weapon`; `get_weapon()`, `equip_weapon(w) -> bool` (definition không hợp lệ → cảnh báo, giữ vũ khí cũ), `unequip_weapon()`, `can_equip(w)` (điểm mở rộng cho luật class ↔ `weapon_type_id`; hiện chỉ kiểm tra dữ liệu); signal `weapon_changed(weapon)`. Không tính damage.

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

Giới hạn: hitbox mỗi bước là hình chữ nhật (chưa có arc thật); chưa có animation; enemy vẫn dùng MeleeAttack đơn (không combo); chưa có luật class ↔ vũ khí.

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

- Độ phân giải pixel-art gốc, viewport scale, chế độ stretch cuối cùng.
- Độ phân giải thiết kế / stretch mode cuối cùng (ảnh hưởng zoom và pixel-perfect).
- Điều khiển nhân vật chính thức (animation, dodge, gamepad, remapping). Input Map di chuyển cơ bản đã có (mục 2c).
- Luồng chuyển scene / menu.
- Công cụ kiểm thử.
