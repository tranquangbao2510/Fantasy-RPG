Công cụ phát triển chạy ngoài game. Thư mục có .gdignore nên Godot không import/không đóng gói khi export.
Chạy từ thư mục gốc project (Godot 4.7.2 console):

1. Sinh lại placeholder art môi trường (world/environment/art/):
   CẢNH BÁO (VISUAL-02.2): phần lớn art đã là art vẽ tay — chạy không lọc sẽ GHI ĐÈ. Chỉ sinh nhóm còn do code
   (fx, logic; nhóm decals gồm cả decal vẽ tay) — xem docs/visual/environment-style-guide.md mục 11.2.
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/placeholder_art/generate_environment_art.gd
   Chỉ sinh một nhóm: đặt biến môi trường ART_ONLY=ground,cliff,trees,plants,rocks,ruins,structures,decals,fx,scenery,logic
   Sau đó import lại:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --import

2. Dựng lại scene Environment Prototype isometric (khu Glade):
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/glade/build_glade_prototype.gd
   CẢNH BÁO: ghi đè world/environment_prototype/environment_prototype.tscn, các scene prop trong
   world/environment/props/, tileset logic và material .tres. Chỉnh sửa tay trên các file đó sẽ mất — commit trước.
   Bố cục (toạ độ lưới i, j) nằm ở đầu script (node tài nguyên M3: RESOURCE_NODES; ruộng M5: FARM_FIELDS, WATER_SOURCES). Cần chạy bước 1 + import trước nếu art chưa có.

3. Kiểm tra sau khi dựng lại:
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_environment_prototype.gd
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_iso_combat.gd

4. Sinh lại SpriteFrames của Player (CHAR-01) sau khi đổi sheet trong entities/player/art/ (PNG + hero_sprites.json):
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --import      (nếu có PNG mới; bật mipmaps/generate trong .import)
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/player_sprites/build_player_sprite_frames.gd
   Ghi đè entities/player/art/hero_sprite_frames.tres. Kiểm tra:
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/player/test_player_sprite.gd

5. Sinh icon placeholder cho item (M1; ô màu theo loại + chữ cái đầu) từ features/items/data/item_database.tres:
     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/item_icons/generate_item_icons.gd
   Ghi đè features/items/icons/<id>.png (chỉ một số item: biến môi trường ICON_ONLY=wood,stone). Sau đó --import,
   bật mipmaps/generate trong .import của icon mới và gán `icon` cho item. Icon thật: thay PNG cùng tên, đừng chạy lại tool.

6. Đo FPS có render của ruộng trồng trọt (TASK M5): ngày / đêm / đêm + 24 ô đầy cây / đêm + 24 ô đầy cây + 15 quái.
   Chạy CÓ CỬA SỔ (không --headless), tắt vsync trong script:
     Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/perf/measure_farm_fps.gd --resolution 1152x648
   Spike frame khi bake navmesh: tests/navigation/test_nav_bake.gd (dòng MEASURE; NAV_SYNC=1 = bake đồng bộ như M4.1).
