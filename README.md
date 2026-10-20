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
Thiết kế game (đọc trước mỗi task): [docs/design/game_design.md](docs/design/game_design.md).
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

- Kiểm thử (headless). Chạy tất cả — mỗi test một tiến trình, thoát mã 1 nếu có test fail; test fail cả khi có lỗi runtime / push_error ngoài dự kiến:

  ```sh
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_all.gd
  ```

  Từng test:

  ```sh
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_environment_prototype.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_iso_combat.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/player/test_player_sprite.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/inventory/test_inventory.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/save/test_save_load.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/survival/test_survival.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/smoke/test_scenes_load.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/crafting/test_crafting.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/gathering/test_gathering.gd
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/night/test_night.gd
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

- TASK 09 — Active skill framework (`features/skills/`, `ui/skills/`): 4 ô kỹ năng **Q / Z / V / X** (ô 2 là C cho tới TASK M3), cast mode Normal / Quick / Instant (bấm nút trên Skill Bar để đổi), hủy ngắm bằng **chuột phải / Esc**.

- TASK 10 — Class & progression prototype (`features/classes/`, `features/character/`, `ui/progression/`): class **Test Fighter** (khởi đầu) / **Test Caster**, character level dùng chung, mastery theo class, signature + passive bổ sung, học / nâng level / tiến hóa kỹ năng, loadout riêng từng class, luật vũ khí theo class. Đến **Trạm huấn luyện** (cột cờ tím phía trên phải quảng trường) và nhấn **E** để mở khóa (debug) / đổi class. **P** mở bảng Class/Progression (nút **[Debug]** để cộng EXP, mastery, học/nâng/tiến hóa kỹ năng); **Esc** đóng.

- TASK 11 — Combat Sandbox (`world/sandbox/`, `ui/debug/`): ở màn hình chính chọn **Combat Sandbox (thử nghiệm)**. Map 60×40 với khu bù nhìn, khu vật cản, đấu trường enemy (Melee Chaser / Stationary Attacker / Ranged) và trạm class. **F3** mở Combat Debug Panel (trạng thái, hồi HP, reset enemy, chọn/chạy lại tình huống, debug info). Cooldown/charges kỹ năng giờ được giữ khi đổi ô hoặc đổi class.

- TASK VISUAL 01 — Environment Visual Foundation (`world/environment/`, `world/environment_prototype/`, [style guide](docs/visual/environment-style-guide.md)): ở màn hình chính chọn **Environment Prototype (Visual 01)**. Khu rừng "Glade" với nền cỏ, đường đất, suối + cầu gỗ, thác nước, vách đá hai tầng (lên bằng **cầu thang đá**), cầu đá tầng cao bắc qua đường mòn (đi trên cầu hoặc dưới gầm), tàn tích cổ, nền thung lũng xa, ánh sáng/sương nhẹ. Zoom lẻ 1×–3× bằng con lăn. Nút góc phải trên bật lưới Terrain Logic. (Art ban đầu là placeholder sinh bằng code — đã thay bằng art vẽ tay, xem VISUAL-02.2.)

- TASK VISUAL-02 — Chuyển Environment Prototype sang **isometric 2:1** (tile thoi 64×32, tầng 64 px): vách hai mặt, quảng trường đá lát thoi, cầu thang chéo, lối đi trên vòm (đi trên hoặc chui dưới), cầu gỗ chéo, thác đổ xuống vực, phông núi + lâu đài mờ. WASD theo hướng màn hình. Thông số + hướng dẫn gen art bằng AI: [style guide](docs/visual/environment-style-guide.md). `test_map` và Combat Sandbox vẫn giữ góc cũ.

- TASK VISUAL-02.1 — Combat theo mặt đất isometric trong Environment Prototype: tầm đánh, hitbox/hurtbox, đạn, vùng chỉ báo/tác dụng kỹ năng đo trên mặt phẳng đất (tròn = ellipse 2:1); đòn/đạn/kỹ năng chỉ trúng cùng tầng; đạn bị vách chặn; enemy cùng tỉ lệ tốc độ dọc với Player. Thanh trượt **[Debug] Tốc độ dọc** trên bảng góc phải trên. Map cũ giữ nguyên hành vi.

- TASK VISUAL-02.2 — Environment Prototype dùng **art vẽ tay** (gen AI + hậu kỳ) cho nền, vách, prop, cầu, decal, phông xa; bóng mềm, FX (sương, tia nắng, bụi sáng) và lưới logic vẫn sinh bằng code (danh sách: style guide mục 11.2). Đường đất sáng và rộng hơn, mép mềm có cỏ lấn; nắng vàng ấm hơn. Tốc độ đi dọc trong map isometric 0.7 (trước 0.5). Cửa sổ game mặc định **1920×1080** (viewport gốc vẫn 1152×648, mọi scene giữ khung hình cũ).

- TASK CHAR-01 — Player dùng **sprite 8 hướng** render từ model 3D (`entities/player/art/`): idle / run / walk, combo attack_1/2/3 (tua khớp nhịp đòn từng vũ khí), cast, hit, death; hướng chọn theo mặt đất (map iso và map cũ). SpriteFrames sinh bằng tool (`tools/player_sprites/`), quy trình model 3D → Mixamo → Blender: [style guide](docs/visual/environment-style-guide.md) mục 12. Enemy vẫn là placeholder.

- TASK M1 — Nền tảng dữ liệu (`features/items/`, `features/inventory/`, `save/`, `ui/inventory/`): item database (10 item thử), túi đồ 24 ô + ô trang bị **Vũ khí / Mũ**, vật phẩm trên đất (đi chạm để nhặt), rương (**E**), Save/Load JSON. Phím: **I** hoặc **Tab** mở/đóng túi đồ (**Esc** đóng) — kéo thả để chuyển, **chuột phải** tách nửa stack, **Shift+click** chuyển nhanh túi ↔ rương, **nhấp đúp** trang bị/tháo, kéo ra ngoài cửa sổ để vứt; **F5** lưu nhanh, **F9** tải nhanh (slot 1); màn hình chính có **Tiếp tục**; tự lưu khi đóng game. Rương + 7 vật phẩm thử đặt trong Environment Prototype. Save ở `%APPDATA%/Godot/app_userdata/Fantasy RPG/saves/`. Chi tiết: [architecture.md](docs/architecture.md) mục 2l.

- TASK M2 (gộp M2.1, thiết kế v0.2) — Thời gian & sinh tồn (`features/time/`, `features/survival/`, `world/environment/time/`): đồng hồ (1 ngày = 20 phút thực, bắt đầu 6:00), ngày/đêm với **bóng tối thật ngoài vùng sáng** quanh nhân vật (đèn lồng ở ô **Tay phụ** mở rộng, đá rune tự sáng), **Mana** cho kỹ năng, **Stamina**, **Đói** (hết đói mất máu), ăn uống (quả mọng, thịt sống, bánh mì, thịt nướng), **giường** (ngủ 18:00–6:00 → sáng hôm sau, hồi máu/mana, tự lưu; thức tới 2:00 thì ngất), **lều** (dựng/ngủ/thu), **chết rơi túi đồ** tại chỗ + hồi sinh ở chỗ nghỉ (giường hoặc lều đã ngủ), mũi tên chỉ túi trên HUD. Phím: **Shift** chạy, **Space** né, **F** dùng nhanh item đang rê chuột trong túi, **chuột phải** trên ô = menu (Dùng / Dựng / Trang bị / Tháo / Tách nửa / Vứt), **E** ngủ / mở menu lều / nhặt lại túi; debug: **F7** tua giờ ×10, **F8** +1 giờ. Không có chỉ số Thể lực. Chi tiết + hệ số: [architecture.md](docs/architecture.md) mục 2m.

- TASK M3 — Lượm nhặt, chế tạo, nấu ăn (`features/gathering/`, `features/crafting/`, `ui/crafting/`): cây / đá / bụi mọng / bụi cỏ khai thác bằng **E** (rìu, cuốc chim, tay không), đồ vào thẳng túi, mọc lại sau vài ngày; rìu / cuốc chim đá có độ bền; **C** mở cửa sổ chế tạo (ô kỹ năng 2 chuyển sang **Z**), bàn chế tạo trong nhà tạm; **lửa trại** dựng được (nguồn sáng, nấu ăn, thêm củi); **đuốc** ở tay phụ. Save v3. Chi tiết: [architecture.md](docs/architecture.md) mục 2n.

- TASK M4 — Đêm nguy hiểm (`features/spawning/`, `entities/enemies/night/`): từ hoàng hôn, quái đêm sinh ngoài màn hình theo bảng spawn — **Bóng ma** (sợ sáng, hút mana), **Sói đêm** (đi bầy 2–3, vây rồi lần lượt lao vào, máu thấp bỏ chạy), **Thây ma rừng** (chậm, trâu, đòn báo trước); không sinh trong vùng sáng của lửa trại / đá rune / đèn giường; bình minh thì tan biến. Cầm đuốc/đèn lồng bị phát hiện từ xa hơn; chạy dễ lộ hơn đi bộ. Rơi da / xương / tinh chất bóng → **giáo xương**, **áo da** (ô Áo mới, giảm sát thương), **đuốc tinh chất**. HUD "Trời sắp tối…" / "Màn đêm buông xuống", viền đỏ khi trúng đòn, mũi tên chỉ quái đang đuổi ngoài màn hình; không ngủ được khi quái gần. Ánh sáng đêm vẽ lại bằng một lớp phủ (hết cháy trắng khi nhiều nguồn sáng chồng nhau). Phím debug: **F1** Bóng ma, **F2** bầy sói, **F4** Thây ma, **F10** vẽ bán kính phát hiện. Save v4. Chi tiết: [architecture.md](docs/architecture.md) mục 2o.

Chưa có ultimate, animation enemy, boss, âm thanh, hotbar, hội thoại hay quest. Mọi chỉ số combat, vũ khí, kỹ năng, class và EXP là placeholder.
