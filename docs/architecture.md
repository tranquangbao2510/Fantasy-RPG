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
| `world/` | Bản đồ, môi trường, camera | Chưa triển khai |
| `ui/` | Thành phần giao diện | Chưa triển khai |
| `data/` | Dữ liệu game dùng chung (`.tres` Resource) | Chưa triển khai |
| `assets/` | Tài nguyên dùng chung (sprite, âm thanh, font) | Chưa triển khai |
| `save/` | Logic lưu / tải game | Chưa triển khai |
| `tests/` | Kiểm thử | Chưa triển khai |
| `addons/` | Plugin bên thứ ba (chỉ khi thật sự cần) | Chưa triển khai |

Thư mục chỉ được tạo khi có nội dung thực tế. Không tạo thư mục, script hoặc class rỗng để "giữ chỗ".

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
