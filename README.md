# Fantasy RPG

Game Fantasy Action RPG 2D, môi trường phong cách High-Resolution Hand-Painted góc isometric 2:1 (từ TASK VISUAL-02; map thử nghiệm cũ vẫn top-down), chiến đấu thời gian thực.

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

- Kiểm thử môi trường (headless, thoát mã 1 nếu có ca thất bại):

  ```sh
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_environment_prototype.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_iso_combat.gd
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

- TASK VISUAL 01 — Environment Visual Foundation (`world/environment/`, `world/environment_prototype/`, [style guide](docs/visual/environment-style-guide.md)): ở màn hình chính chọn **Environment Prototype (Visual 01)**. Khu rừng "Glade" với nền cỏ, đường đất, suối + cầu gỗ, thác nước, vách đá hai tầng (lên bằng **cầu thang đá**), cầu đá tầng cao bắc qua đường mòn (đi trên cầu hoặc dưới gầm), tàn tích cổ, nền thung lũng xa, ánh sáng/sương nhẹ. Zoom lẻ 1×–3× bằng con lăn. Nút góc phải trên bật lưới Terrain Logic. **Art là placeholder sinh bằng code**, chưa phải production art.

- TASK VISUAL-02 — Chuyển Environment Prototype sang **isometric 2:1** (tile thoi 64×32, tầng 64 px): vách hai mặt, quảng trường đá lát thoi, cầu thang chéo, lối đi trên vòm (đi trên hoặc chui dưới), cầu gỗ chéo, thác đổ xuống vực, phông núi + lâu đài mờ. WASD theo hướng màn hình. Thông số + hướng dẫn gen art bằng AI: [style guide](docs/visual/environment-style-guide.md). `test_map` và Combat Sandbox vẫn giữ góc cũ.

- TASK VISUAL-02.1 — Combat theo mặt đất isometric trong Environment Prototype: tầm đánh, hitbox/hurtbox, đạn, vùng chỉ báo/tác dụng kỹ năng đo trên mặt phẳng đất (tròn = ellipse 2:1); đòn/đạn/kỹ năng chỉ trúng cùng tầng; đạn bị vách chặn; enemy cùng tỉ lệ tốc độ dọc với Player. Thanh trượt **[Debug] Tốc độ dọc** trên bảng góc phải trên. Map cũ giữ nguyên hành vi.

Chưa có ultimate, mana/stamina, animation, inventory, hội thoại, quest hay save. Mọi chỉ số combat, vũ khí, kỹ năng, class và EXP là placeholder.
