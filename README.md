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
Quy ước commit: [docs/git_conventions.md](docs/git_conventions.md).

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

- TASK 04 — Player placeholder (`entities/player/`), di chuyển 8 hướng bằng **WASD** hoặc **phím mũi tên**, bị chặn bởi vật cản và mép bản đồ.

- TASK 05 — Camera (`world/camera/`): theo player, smoothing, **lăn chuột** để zoom 2×–4× (mức nguyên), không nhìn ra ngoài bản đồ.

- TASK 06 — Interaction System (`features/interaction/`, `ui/interaction/`): đến gần bảng thông báo, rương hoặc tinh thể thử nghiệm và nhấn **E**.

- TASK 07 — Combat prototype: **chuột trái** chém về phía con trỏ, Training Dummy và Simple Enemy, HP/HUD, số sát thương, bị hạ gục; **R** để reset thử nghiệm.

- TASK 08 — Vũ khí data-driven (`features/combat/weapons/`): combo đánh thường theo vũ khí, knockback enemy. Phím debug **1/2/3** đổi Test Sword / Dagger / Heavy Weapon.

- TASK 09 — Active skill framework (`features/skills/`, `ui/skills/`): 4 ô kỹ năng **Q / C / V / X**, cast mode Normal / Quick / Instant (bấm nút trên Skill Bar để đổi), hủy ngắm bằng **chuột phải / Esc**.

- TASK 10 — Class & progression prototype (`features/classes/`, `features/character/`, `ui/progression/`): class **Test Fighter** (khởi đầu) / **Test Caster**, character level dùng chung, mastery theo class, signature + passive bổ sung, học / nâng level / tiến hóa kỹ năng, loadout riêng từng class, luật vũ khí theo class. Đến **Trạm huấn luyện** (cột cờ tím phía trên phải quảng trường) và nhấn **E** để mở khóa (debug) / đổi class. **P** mở bảng Class/Progression (nút **[Debug]** để cộng EXP, mastery, học/nâng/tiến hóa kỹ năng); **Esc** đóng.

- TASK 11 — Combat Sandbox (`world/sandbox/`, `ui/debug/`): ở màn hình chính chọn **Combat Sandbox (thử nghiệm)**. Map 60×40 với khu bù nhìn, khu vật cản, đấu trường enemy (Melee Chaser / Stationary Attacker / Ranged) và trạm class. **F3** mở Combat Debug Panel (trạng thái, hồi HP, reset enemy, chọn/chạy lại tình huống, debug info). Cooldown/charges kỹ năng giờ được giữ khi đổi ô hoặc đổi class.

Chưa có ultimate, mana/stamina, animation, inventory, hội thoại, quest hay save. Mọi chỉ số combat, vũ khí, kỹ năng, class và EXP là placeholder.
