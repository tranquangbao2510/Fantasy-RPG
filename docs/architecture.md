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
| `features/` | Module gameplay (mỗi tính năng một thư mục con, vd. `features/combat/`) | Chưa triển khai |
| `entities/` | Player, NPC, enemy (scene ghép từ component) | Chưa triển khai |
| `world/` | Bản đồ, môi trường, camera | Đã triển khai (`world.tscn`, `world.gd`, `maps/test_map/`) |
| `ui/` | Thành phần giao diện | Chưa triển khai |
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
└── CameraContainer (Node2D)    — camera
```

- **Main Scene** là entry point: màn hình khởi động tạm và chuyển vào World. Không giữ trạng thái game.
- **World Scene** là gốc của môi trường game. Không phụ thuộc Main Scene, mở và chạy độc lập bằng F6.
- `world.gd` chỉ cung cấp public API trả về các container (`get_map_container()`, `get_entity_container()`, ...). Không chứa logic gameplay.
- Chuyển scene dùng trực tiếp `change_scene_to_file()`; chưa có SceneManager, loading screen hay hiệu ứng chuyển cảnh.

Nguyên tắc đặt node vào World:

- Bản đồ → `MapContainer`; entity → `EntityContainer`; camera → `CameraContainer`; phần môi trường không thuộc bản đồ (nền, thời tiết, ánh sáng) → `Environment`.
- Không đặt node gameplay trực tiếp dưới `World`.

Chưa triển khai: entity, camera.

## 2b. Bản đồ thử nghiệm — TestMap [Đã triển khai, placeholder]

```
world/maps/test_map/
├── test_map.tscn               — TestMap (Node2D, texture_filter = Nearest)
│   ├── GroundLayer (TileMapLayer)   — cỏ, đường đất, nền đá; không collision
│   ├── DetailLayer (TileMapLayer)   — hoa, sỏi (trang trí phẳng); không collision
│   └── ObstacleLayer (TileMapLayer) — đá, bụi cây; có collision
├── tileset/test_tileset.tres   — TileSet dùng lại được (resource riêng)
└── assets/test_tiles.png       — atlas placeholder 128×64 (4×2 ô)
```

- **Tile size:** 32×32 (thử nghiệm, chưa phải quyết định chính thức). Map 30×20 ô = 960×640 px, đặt tại gốc tọa độ, nằm gọn trong viewport mặc định 1152×648 (chưa có camera).
- **Atlas (source 0):** hàng 0 — `(0,0)` cỏ, `(1,0)` cỏ biến thể, `(2,0)` đất, `(3,0)` đá lát; hàng 1 — `(0,1)` hoa, `(1,1)` sỏi, `(2,1)` đá cản, `(3,1)` bụi cây cản.
- **Lọc texture:** đặt `texture_filter = Nearest` trên node `TestMap` (không đổi cấu hình toàn project). Thiết lập pixel-art toàn cục sẽ quyết định cùng độ phân giải chính thức.
- Dữ liệu tile lưu trực tiếp trong `test_map.tscn`; không có script sinh map lúc chạy.
- Đồ họa, bố cục và kích thước map đều là placeholder.

**Chỉnh sửa trong Editor:** mở `world/maps/test_map/test_map.tscn` → chọn một TileMapLayer → tab **TileMap** ở dock dưới → chọn tile và vẽ. Sửa collision/tile: mở `test_tileset.tres` → tab **TileSet** → **Paint** → Physics Layer 0.

### Collision

| Physics layer | Tên | Dùng cho |
|---|---|---|
| 1 | `world` | Vật cản tĩnh của bản đồ (tile trong ObstacleLayer) |

- TileSet physics layer 0: `collision_layer = 1`, `collision_mask = 0` (vật cản tĩnh không cần dò).
- Chỉ tile đá `(2,1)` và bụi `(3,1)` có polygon (24×24, lệch xuống dưới theo chân vật). Ground và Detail tắt `collision_enabled`.
- **TASK 04:** player cần `collision_mask` chứa layer 1 để bị chặn bởi vật cản. Layer của player sẽ quyết định trong TASK 04.

### Thứ tự hiển thị và Y-sort

- Thứ tự vẽ theo thứ tự node: Ground → Detail → Obstacle → (EntityContainer) → ...
- `EntityContainer` bật Y-sort; entity sau này nên đặt origin ở chân (điểm tiếp xúc mặt đất).
- Vật cản hiện tại **thấp**, không Y-sort; entity luôn vẽ đè lên vật cản. Đây là giới hạn được chấp nhận.
- Hướng xử lý vật thể cao (cây, tường) cho task sau: đặt chúng chung một node cha có Y-sort với entity (vd. TileMapLayer có `y_sort_enabled` cùng cấp Y-sort với entity, hoặc scene vật thể riêng trong cùng cây Y-sort). Không dùng Z-index tùy tiện.

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
- Hệ thống camera.
- Điều khiển nhân vật và Input Map.
- Luồng chuyển scene / menu.
- Công cụ kiểm thử.
