# Báo cáo TASK M7-fix — `shade_never_enters_light` lúc pass lúc fail

## 1. Nguyên nhân thật

Tôi ghi log từng frame (vị trí, state, vận tốc, hover_point, số va chạm) cho Bóng ma với 8 seed, đo khoảng cách tới **cả** tâm `Campfire` lẫn tâm `VisionLight`:

| seed | `_hover_sign` | gần nhất tới tâm lửa trại | gần nhất tới tâm VisionLight | frame `light.contains()` |
|---|---|---|---|---|
| 0, 1, 4 | +1 | **298.44** | 305.18 | 0 |
| 2, 3, 5, 6, 7 | −1 | 316.88 | 313.51 | 0 |

(bán kính 300, `ground_squash` 0.5)

- **Bóng ma chưa từng vào vùng sáng thật.** Không frame nào `VisionLight.contains(vị trí)` đúng; nó luôn cách tâm đèn ≥ 305 px (mép + `light_margin` 6 của `_avoid_light`).
- Test cũ đo khoảng cách từ `fire.global_position`, nhưng node `VisionLight` trong `campfire.tscn` nằm ở `position = (0, -4)` (màn hình) = **8 px mặt đất về phía bắc**. Khi Bóng ma lượn phía bắc, khoảng cách tới tâm lửa trại ngắn hơn khoảng cách tới tâm đèn khoảng 7 px, nên test đọc ra 298.44 (đúng con số "lấn 1.6 px" ghi trong M7.md).
- Lúc pass lúc fail vì `_hover_sign` bốc ngẫu nhiên (`_rng.randomize()`) theo tỉ lệ 50/50: +1 thì đi vòng phía bắc (fail), −1 thì đi phía nam (pass). Khớp với 4/6 lần fail ghi ở M7.md.
- Nghi vấn "va chạm / move_and_slide / _snap_to_navmesh đẩy qua mép" **không** xảy ra trong ca này. Khi đó số va chạm bằng 0, và quái không va với Player (mask chỉ có layer 1) hay với quái khác. Tuy vậy, nhìn trước của `_avoid_light` thật sự không phải ràng buộc cứng: **knockback** (và về lý thuyết trượt dọc vật cản, lực tách bầy) có thể đẩy Bóng ma vào vùng sáng. Ca test mới ở mục 3 cho thấy điều đó: tắt ràng buộc thì Bóng ma bị đẩy vào tới 292.95 / 300.

## 2. Sửa

`Enemy._keep_out_of_light()` (chỉ cho `light_averse`) chạy ngay sau `move_and_slide()`:

- Nếu trước khi di chuyển còn ở ngoài mà sau khi di chuyển `VisionLight.find_safe_light(..., margin 0)` tìm thấy đèn, thì kéo về **đúng mép** (bán kính + 0.05 px) theo hướng ra ngoài trên mặt đất, rồi bỏ thành phần hướng vào trong của `velocity` **và** của knockback đang giảm dần (`KnockbackComponent.set_velocity`). Nếu chỉ bỏ ở velocity thì frame sau knockback lại đẩy vào.
- Điểm mép chỉ được nhận khi nằm trên navmesh tầng mình và đường tìm tới đó gần như thẳng (≤ 1.2 × đường thẳng + 1 px), tức là không xuyên tường. Nếu không đạt, thử 48 hướng quanh mép (ưu tiên gần hướng ra ngoài), mỗi điểm được kéo về navmesh theo đường tới được, rồi lấy điểm gần nhất nằm ngoài vùng sáng.
- Map chưa có navmesh thì dùng `move_and_collide` tới mép, để vật cản vẫn chặn.
- **Khác với spec một chỗ:** nếu Bóng ma đã ở trong vùng sáng **từ trước** frame đó (lửa trại vừa nhóm đè lên nó), tôi không kéo. Lý do: kéo lúc đó là dịch chuyển tức thời hàng trăm px. Thay vào đó nó vẫn đi bộ ra (`_light_escape`), giữ nguyên ca `shade_leaves_light`. Luật "không bước vào" vẫn được đảm bảo, vì mọi frame bước từ ngoài vào đều bị chặn.

Test (`tests/night/test_night.gd`):
- `shade.set_rng_seed(1)` (hàm mới `Enemy.set_rng_seed`, bốc lại `_hover_sign` / `_circle_angle`). Seed 1 cho đi vòng phía bắc, đúng ca từng fail.
- `shade_never_enters_light` giờ **chặt hơn**: đo từ tâm `VisionLight`, đếm số frame `light.contains(vị trí)` phải bằng 0, và khoảng cách gần nhất ≥ bán kính, **không còn sai số 1 px**.
- Ca mới `shade_pushed_stays_out`: đặt Bóng ma cách mép 2 px, knockback 600 px/s hướng vào tâm. Sau 1 physics frame phải ở ngoài, cách mép < 3 px, nằm trên navmesh, và tốc độ hướng vào trong (của cả velocity lẫn knockback) ≤ 0. Đã kiểm tra ngược: khi tắt `_keep_out_of_light()`, ca này FAIL (`292.95 / 300, tốc độ vào trong 584.48`).

## 3. test_night 20 lần liên tiếp

Không có tiến trình Godot nào khác chạy song song.

| run | exit | RESULT | shade_never_enters_light | shade_pushed_stays_out |
|---|---|---|---|---|
| 1–20 | 0 (cả 20) | 105/105 (cả 20) | PASS, gần nhất 305.18 / 300, 0 frame trong vùng sáng | PASS, 300.05 / 300, tốc độ vào trong −0.00 |

Log đầy đủ của từng lần nằm ở mục 5.

## 4. Toàn bộ suite

```
PASS res://tests/app/test_app_shell.gd — RESULT 128/128 passed (24.4s)
PASS res://tests/art/test_object_art.gd — RESULT 40/40 passed (13.3s)
PASS res://tests/crafting/test_crafting.gd — RESULT 40/40 passed (1.3s)
PASS res://tests/environment/test_environment_prototype.gd — RESULT 17/17 passed (40.3s)
PASS res://tests/environment/test_iso_combat.gd — RESULT 30/30 passed (11.3s)
PASS res://tests/farming/test_farming.gd — RESULT 85/85 passed (19.5s)
PASS res://tests/gathering/test_gathering.gd — RESULT 92/92 passed (11.1s)
PASS res://tests/inventory/test_inventory.gd — RESULT 52/52 passed (1.0s)
PASS res://tests/navigation/test_nav_bake.gd — RESULT 16/16 passed (14.0s)
PASS res://tests/night/test_night.gd — RESULT 105/105 passed (69.0s)
PASS res://tests/player/test_player_sprite.gd — RESULT 57/57 passed (13.8s)
PASS res://tests/polish/test_m6_1_fixes.gd — RESULT 25/25 passed (14.2s)
PASS res://tests/save/test_save_load.gd — RESULT 60/60 passed (7.9s)
PASS res://tests/smoke/test_scenes_load.gd — RESULT 4/4 passed (5.9s)
PASS res://tests/survival/test_survival.gd — RESULT 94/94 passed (21.3s)
TESTS 15/15 passed
```

Chạy `tests/run_all.gd` một lần sau khi sửa, không có Godot nào khác chạy song song: **15/15 pass** (gồm test_nav_bake 16/16).

## 5. Log 20 lần chạy

```
run 1 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 2 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 3 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 4 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 5 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 6 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 7 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 8 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 9 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 10 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 11 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 12 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 13 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 14 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 15 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 16 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 17 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 18 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 19 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
run 20 exit=0 RESULT 105/105 passed | PASS shade_never_enters_light gần nhất 305.18 / bán kính 300, 0 frame trong vùng sáng PASS shade_pushed_stays_out 300.05 / 300, tốc độ vào trong -0.00
```
