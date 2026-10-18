# Fantasy RPG

Game Fantasy Action RPG 2D, phong cách Detailed Pixel Art, góc nhìn three-quarter, chiến đấu thời gian thực.

- Nền tảng chính: Windows Desktop (.exe)
- Nền tảng phụ: Web

## Công nghệ

| Thành phần | Lựa chọn |
|---|---|
| Engine | Godot 4.7.2 Standard (không dùng bản .NET) |
| Ngôn ngữ | GDScript, static typing |
| Renderer | Compatibility (`gl_compatibility`) |
| Kiến trúc | Hybrid / Feature-based, Composition + base class mỏng |
| Dữ liệu thiết kế | Custom Resources (`.tres`) |
| Quản lý mã nguồn | Git |

Chi tiết kiến trúc: [docs/architecture.md](docs/architecture.md).
Quy tắc cộng tác cho AI agent: [docs/agent_rules.md](docs/agent_rules.md).

## Mở project

1. Mở Godot 4.7.2 (đúng phiên bản; không mở bằng bản khác để tránh tự động chuyển đổi project).
2. Project Manager → **Import** → chọn file `project.godot` trong thư mục này.
3. Lần mở đầu, Godot sẽ tự tạo thư mục cache `.godot/` (đã được bỏ qua trong Git).

## Chạy

- **F5**: chạy project (Main Scene là `res://app/main.tscn`), nhấn **Vào game** để chuyển sang World Scene.
- **F6**: chạy scene đang mở (vd. mở `world/world.tscn` để chạy World độc lập).
- Dòng lệnh (headless, kiểm tra nhanh):

  ```sh
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 30
  ```

## Trạng thái hiện tại

- TASK 01 — nền tảng: cấu trúc thư mục, Main Scene tạm thời, cấu hình Godot, Git và tài liệu.
- TASK 02 — World Scene với các container (Environment, Map, Entity, Camera) và nút "Vào game" từ Main Scene.
- TASK 03 — Bản đồ thử nghiệm `world/maps/test_map/` (TileMapLayer, tile 32×32, collision vật cản). Mở `test_map.tscn` để chỉnh sửa map.

Chưa có gameplay, player, camera, menu hay hệ thống nào khác.
