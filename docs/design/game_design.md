# Game Design — Fantasy RPG

> Tài liệu định hướng thiết kế. **Mọi task mới phải đọc file này trước** để biết hệ thống đang làm phục vụ mục tiêu gì.
> Trạng thái: **v0.2 (2026-10-20)**, cập nhật theo ý tưởng chi tiết của chủ dự án; đánh dấu trạng thái sau M2 và task M3 (lượm nhặt, chế tạo, nấu ăn — kéo một phần mốc M4 lên trước). Mục **[Chưa quyết định]** chưa được chốt, không tự chọn thay chủ dự án.

---

## 1. Tóm tắt

Action RPG 2D isometric, đồ họa vẽ tay, trong một **thế giới fantasy** có phép thuật, kiếm thuật, nhiều phe phái, thành bang và sinh vật.

Người chơi là **một nhà mạo hiểm bắt đầu từ con số 0**: tỉnh dậy giữa rừng sau khi đội mạo hiểm bị quái tấn công tan tác, đồng đội lưu lạc, đồ đạc mất sạch. Không nghề, không tiền, không quen ai, gặp quái chỉ biết chạy hoặc đấm tay không. Từ đó người chơi:
- tìm đường vào làng, học một **class**;
- kiếm tiền, sửa sang căn nhà nhỏ tàn tạ;
- trồng trọt, săn bắt, chế tạo để sống sót;
- kết thân với NPC, chọn phe;
- dần mạnh lên và đi xa hơn.

Game chơi dài, không có điểm kết thúc cứng. Có mạch nhiệm vụ chính dẫn dắt (tìm lại đồng đội, sự thật về cuộc tấn công).

- **Nền tảng:** Windows desktop (chính), Web (phụ)
- **Engine:** Godot 4.7.2, GDScript, Compatibility renderer (xem `docs/architecture.md`)
- **Mục đích hiện tại:** luận văn tốt nghiệp ngành Kỹ thuật Phần mềm. Bảo vệ khoảng 10/2027. Đề tài tự do.

## 2. Trụ cột thiết kế (Design Pillars)

Mọi tính năng mới phải phục vụ ít nhất một trụ cột. Không phục vụ trụ cột nào thì không làm.

1. **Từ con số 0 đi lên.** Khởi đầu yếu và nghèo thật sự. Mỗi bước tiến (class đầu tiên, món vũ khí đầu tiên, căn nhà sửa xong) phải cảm nhận được rõ ràng.
2. **Chiến đấu hành động có chiều sâu.** Mỗi class có vũ khí, chiêu thức, combo và lộ trình nâng cấp riêng. Người chơi giỏi thì đánh khác người chơi mới.
3. **Sinh tồn và một mái nhà.** Đói, đêm tối, quái đêm buộc người chơi phải chuẩn bị. Nhà là nơi an toàn để quay về, sửa sang dần.
4. **Một thế giới sống, có phe phái.** NPC có lịch sinh hoạt, nhớ người chơi, có thể thành bạn đồng hành. Các phe (Người, Thần, Quỷ, Quái vật rừng...) có thái độ khác nhau tùy hành động của người chơi.

## 3. Trải nghiệm và vòng lặp

### 3.1 Mở đầu (Prologue, ~10–15 phút)

1. Cutscene ngắn hoặc màn hình chữ: đội mạo hiểm bị phục kích ban đêm.
2. Tỉnh dậy giữa rừng, sáng sớm. **Không class, túi trống, HP thấp, đói.** Có HUD hướng dẫn cơ bản.
3. Học điều khiển: đi, chạy, né, **đấm tay không**, nhặt quả ăn.
4. Gặp quái yếu: đánh tay không được nhưng vất vả. Gặp quái mạnh: phải chạy.
5. Lần theo đường mòn tới **làng**. NPC đầu tiên chỉ đường tới **người dạy nghề**, và tới **căn nhà nhỏ bỏ hoang** người chơi được ở tạm.
6. Học class đầu tiên (trả phí rẻ hoặc miễn phí lần đầu **[Chưa quyết định]**), nhận vũ khí và chiêu cơ bản của class.
7. Mở khóa thế giới: bảng nhiệm vụ, chợ, nhà.

### 3.2 Vòng lặp ngày (5–15 phút)

```
Thức dậy ở nhà / lều
  → chăm vườn, nấu ăn, chế tạo, sửa nhà
  → vào làng: nhận/trả nhiệm vụ, mua bán, gặp NPC
  → ra ngoài: khám phá, săn bắt, hái lượm, đánh quái, làm nhiệm vụ
  → (đói / mệt / trời tối, quái đêm mạnh và đông) → về nhà hoặc dựng lều
  → ngủ → ngày mới
```

### 3.3 Vòng lặp tiến triển (nhiều ngày)

```
Nhiệm vụ + săn quái → tiền, EXP, nguyên liệu
  → học/nâng class, mua đồ, nâng cấp nhà, chế trang bị và trang phục
  → vào được vùng nguy hiểm hơn → phần thưởng tốt hơn
Thân thiết NPC → giảm giá, công thức, nhiệm vụ riêng, đồng đội đi theo, phụ việc nhà
Uy tín phe phái → mở/khóa vùng, cửa hàng, nhiệm vụ; thay đổi thái độ của sinh vật và NPC
```

### 3.4 Chết

- Hết HP: **túi đồ rơi thành một túi tại chỗ chết**, người chơi **hồi sinh ở nhà**. **Không mất tiền.** ✅ (M2: túi `DeathBag` chứa toàn bộ túi đồ, hồi sinh ở giường "nhà" hoặc lều đã ngủ với 50% HP, mũi tên chỉ túi trên HUD)
- Quay lại chỗ chết nhặt lại túi. Đã chốt (M2.1): trang bị đang mặc **không rơi**; chết lần nữa trước khi nhặt → **túi mới, túi cũ vẫn giữ**. **[Chưa quyết định]** Túi đồ có biến mất sau N ngày không (M2: không biến mất; task M3: tối đa 5 túi/map — túi thứ 6 làm túi cũ nhất biến mất, túi rỗng tự xóa).

## 4. Hệ thống

Ký hiệu: ✅ đã có (prototype) · 🟡 có một phần · ⬜ chưa có.

### 4.1 Thế giới & khám phá 🟡
- Thế giới nhiều **vùng** (rừng, làng, tàn tích, hang, lãnh địa các phe...), mỗi vùng có quái, tài nguyên, NPC riêng.
- Isometric 2:1, elevation nhiều tầng, đồ họa vẽ tay ✅ (xem `docs/visual/environment-style-guide.md`).
- **[Chưa quyết định]** Thế giới liền mạch (load theo vùng) hay các map nối qua cổng. Đề xuất cho luận văn: **map rời nối qua cổng/lối đi** (đơn giản, ổn định), giữ khả năng chuyển sang liền mạch sau.

### 4.2 Class 🟡
- **Ban đầu không có class**: chỉ đấm tay không (combo đấm 2–3 đòn, sát thương thấp), không có kỹ năng.
- Học class ở **NPC dạy nghề trong làng**. Class: **Kiếm sĩ, Sát thủ, Pháp sư, Cung thủ** (có thể thêm sau).
- Mỗi class: vũ khí đặc trưng, bộ kỹ năng riêng, combo riêng, **tiến độ mastery và nâng cấp kỹ năng riêng** (hệ thống tiến độ riêng từng class đã có ✅).
- **Đổi class**: tại **một NPC chung**, **tốn tiền** và có **thời gian chờ (cooldown)** giữa hai lần đổi. Tiến độ các class giữ nguyên khi đổi.
- **Không có class lai**: đang là class nào chỉ dùng vũ khí và kỹ năng của class đó.
- Vũ khí ngoài class đang chọn: **[Chưa quyết định]** không trang bị được hay trang bị được nhưng không dùng kỹ năng.

### 4.3 Chiến đấu ✅🟡
- Đã có: combo theo vũ khí, 4 ô kỹ năng (Normal/Quick/Instant), class/mastery/passive, tiến hóa kỹ năng, combat trên mặt phẳng iso, lọc theo tầng.
- Đã có (M2): **mana** (kỹ năng tốn mana) ✅, **stamina** (chạy Shift, né Space) ✅, **né (dodge)** có i-frame ✅.
- Cần thêm: **đấm tay không**, quái có sprite thật + tìm đường, quái đêm, boss.

### 4.4 Sinh tồn 🟡
- **Đói (0–100):** giảm theo thời gian, nhanh hơn khi chạy/đánh. **Hết đói thì máu tụt dần.** ✅ (M2; ăn uống qua item `consumable` ✅)
- **Không có chỉ số Thể lực/Mệt** (đã chốt 2026-10-20). Lý do để ngủ: qua đêm nguy hiểm, hồi máu, tự lưu.
- Nguồn đồ ăn: **hái trái cây**, **tự trồng**, **săn thú lấy thịt** (nấu chín ngon hơn), **mua ở chợ**. (M2: mới có đồ ăn nhặt được + trong rương; task M3: hái bụi mọng, enemy rơi thịt sống, nấu ở lửa trại ✅; trồng/thú săn/chợ ở M4–M5)
- Không có khát, nhiệt độ, bệnh trong phạm vi luận văn.

### 4.5 Ngày/đêm & tầm nhìn 🟡
- Đồng hồ trong game, mặc định **1 ngày = 20 phút thực** (chỉnh được). ✅ Đã chốt mặc định (M2): 1 ngày = 1200 s thực, bắt đầu 6:00; bình minh 5:00, ngày 7:00, hoàng hôn 17:00, đêm 19:00 (`features/time/time_settings.tres`).
- **Ban đêm tầm nhìn thu nhỏ**: ngoài bán kính quanh nhân vật là bóng tối thật (không chỉ tối màu). ✅ (bán kính 160 px mặt đất ≈ 3.5 ô)
- **Đèn lồng**: item cầm tay phụ, mở rộng tầm nhìn. ✅ (ô offhand, +96 px). **[Chưa quyết định]** có tốn dầu không (M2: chưa tốn).
- Nguồn sáng trong thế giới: đuốc, lửa trại, đá rune, đèn nhà. ✅ (M2: đá rune, đèn cạnh giường; task M3: lửa trại, đuốc ở tay phụ; đêm còn ánh trăng ~13 %)
- **Quái ban đêm mạnh hơn và đông hơn.** ⬜ (M6; đã có signal `darkness_changed`)

### 4.6 Ngủ ✅
- M2: giường (nhà tạm trong Glade) + lều (dựng/ngủ/thu); ngủ 18:00–trước 6:00, thức tới 2:00 thì ngất. Task M3: giường hồi 100 % HP, lều 70 % HP (mana 100 % cả hai); ngất tỉnh tại chỗ lúc 6:00, đói −10.
- Ngủ ở **giường trong nhà**, hoặc **dựng lều** ở ngoài (lều là item, dựng/thu được).
- Ngủ → sang sáng hôm sau, hồi HP/mana, **tự lưu game**.
- **[Chưa quyết định]** Ngủ lều ngoài trời có rủi ro không (bị quái tấn công, hồi ít hơn).

### 4.7 Lượm nhặt & săn bắt 🟡
- Task M3: cây, tảng đá, bụi mọng, bụi cỏ trong Glade; rìu đá + cuốc chim đá có độ bền; mọc lại theo ngày ✅. Chưa có: liềm, cấp công cụ, thú săn.
- Node tài nguyên: cây (gỗ), đá/quặng, bụi (quả, thảo dược)... **mọc lại** sau N ngày.
- Cần công cụ (rìu, cuốc chim, liềm), công cụ có cấp.
- **Săn thú** trong rừng (thú hiền bỏ chạy, thú dữ tấn công) rơi thịt, da, xương.

### 4.8 Trồng trọt ⬜
- Vườn cạnh nhà, mở rộng qua nâng cấp nhà.
- Cuốc đất → gieo → tưới mỗi ngày → lớn theo ngày → thu hoạch.
- NPC thân thiết có thể **thu hoạch hộ**.

### 4.9 Chế tạo 🟡
- Task M3: công thức `.tres` (RecipeDefinition), chế tạo tức thì, phím C; trạm bàn chế tạo (Glade) + lửa trại (nấu ăn) ✅. Chưa có: mở khóa công thức, chế tạo có thời gian chờ, trạm trong nhà theo nâng cấp.
- Trạm trong nhà (mở dần qua nâng cấp): bàn chế tạo, bếp, bàn thuốc...
- Công thức dạng dữ liệu `.tres`, mở khóa qua sách, NPC, mastery.
- Chế được: công cụ, vũ khí, **trang phục**, đồ ăn, thuốc, lều, đèn.

### 4.10 Nhà ⬜
- Mới vào được **một căn nhà nhỏ tàn tạ** trong/gần làng.
- **Nâng cấp kiểu chọn sẵn**: menu liệt kê các hạng mục (sửa mái, thêm phòng, bếp, vườn, kho, xưởng...), **bấm chọn → trừ tiền** (có thể thêm nguyên liệu **[Chưa quyết định]**) → nhà đổi ngoại hình và mở chức năng. **Không xây tự do.**
- Nơi hồi sinh khi chết.

### 4.11 Túi đồ, trang bị & trang phục ✅🟡
- Đã có: item database, túi đồ 24 ô, rương, nhặt/vứt, ô trang bị vũ khí + mũ ✅ (M1), ô tay phụ (đèn lồng), dùng item (ăn, dựng lều) ✅ (M2).
- **Trang phục có cả chỉ số lẫn ngoại hình**: mũ, áo, quần, giày, phụ kiện...
- **Menu nhân vật/trang phục**: hiển thị **"hình dạng thật" của nhân vật** — chi tiết, đẹp, khác hẳn sprite gameplay nhỏ. Thay đồ thấy ngay trên nhân vật này. Xem mục 7 (vấn đề kỹ thuật).
- Ngoài thế giới, sprite gameplay đổi theo trang phục ở mức nào: **[Chưa quyết định]** (đề xuất: chỉ các món lớn hoặc theo bộ).

### 4.12 Kinh tế ⬜
- Tiền tệ. Nguồn tiền: nhiệm vụ, bán nông sản/nguyên liệu/đồ.
- Tiêu: học/đổi class, nâng cấp nhà, chợ, cửa hàng.

### 4.13 NPC, quan hệ & đồng đội ⬜
- NPC có tên, tính cách, phe, lịch sinh hoạt theo giờ, sở thích quà.
- **Độ thân thiết** tăng khi trò chuyện, tặng quà, làm nhiệm vụ.
- Mốc thân thiết mở: hội thoại, giảm giá, công thức, nhiệm vụ riêng, và **trợ giúp**:
  - **thu hoạch ruộng** hộ;
  - **đi theo đánh quái chung** (đồng đội có AI chiến đấu).

### 4.14 Phe phái ⬜
- Các phe: **Người, Thần, Quỷ, Quái vật/sinh vật rừng** (có thể thêm).
- Mỗi phe có **uy tín** với người chơi (ví dụ −100 … +100). Thay đổi qua nhiệm vụ, tiêu diệt thành viên phe, lựa chọn trong hội thoại.
- Uy tín ảnh hưởng: thái độ NPC/sinh vật (thân thiện/trung lập/thù địch), giá cả, nhiệm vụ mở được, vùng vào được.
- **[Chưa quyết định]** Các phe có xung đột nhau không (giúp phe này thì phe kia ghét).

### 4.15 Nhiệm vụ ⬜
- Loại: thu thập, tiêu diệt, giao hàng, hộ tống, nói chuyện, khám phá.
- Nguồn: mạch chính, NPC, **bảng nhiệm vụ trong làng**, phe phái.
- Phần thưởng: **tiền, EXP, nguyên liệu**, uy tín, thân thiết.

### 4.16 Lưu game ✅🟡
- Đã có: SaveService, JSON, ghi an toàn, backup, migration, F5/F9, tự lưu khi thoát ✅ (M1).
- Thêm dần theo từng hệ thống. Tự lưu khi ngủ. ✅ (M2: tự lưu khi ngủ; schema 2 + migration v1 → v2)
- **Quy tắc kỹ thuật:** dữ liệu thiết kế `.tres` chỉ đọc; trạng thái người chơi là JSON; mọi thứ cần lưu có **ID string ổn định**.

## 5. Phạm vi luận văn (MVP — mục tiêu tới ~08/2027)

Mỗi hệ thống có **một bản nhỏ nhưng chạy thật**, nối thành trải nghiệm hoàn chỉnh từ mở đầu tới boss đầu tiên. Ưu tiên **chạy được, có test, có docs** hơn nhiều nội dung.

| Hệ thống | Nội dung tối thiểu cho luận văn |
|---|---|
| Thế giới | **Rừng mở đầu**, **Làng**, **1 vùng nguy hiểm** (tàn tích/hang) + 1 vùng lãnh địa phe (nếu kịp) |
| Mở đầu | Đoạn prologue + hướng dẫn, tay không → vào làng → học class |
| Class | **Kiếm sĩ + Pháp sư làm đầy đủ** (vũ khí, 4 kỹ năng, combo, mastery, animation). **Sát thủ + Cung thủ: mục tiêu mở rộng** (làm nếu kịp). Đấm tay không. NPC dạy nghề + NPC đổi class (tiền + cooldown) |
| Chiến đấu | Mana, stamina, né. **4–5 loại quái** (gồm thú săn được, quái đêm), **1 boss** |
| Sinh tồn | Đói, ăn uống, ngủ, ngày/đêm, tầm nhìn đêm + đèn, lều |
| Lượm nhặt/săn | 3 công cụ, ~8 tài nguyên, node mọc lại, 2 loài thú săn |
| Trồng trọt | Vườn nhà, 4 loại cây |
| Chế tạo | 3 trạm, ~20 công thức (gồm đồ ăn, lều, đèn, 1 bộ trang phục) |
| Nhà | Nhà tàn tạ + **4–5 hạng mục nâng cấp** bằng tiền, đổi ngoại hình |
| Trang phục | 4 slot (mũ, áo, quần, giày) có chỉ số + **menu nhân vật hiển thị "hình dạng thật"** |
| Kinh tế | Tiền, chợ (mua/bán), cửa hàng NPC |
| NPC | **4–5 NPC** có lịch, hội thoại, thân thiết; **1 NPC đồng đội** đi theo đánh quái; thu hoạch hộ |
| Phe phái | **4 phe có uy tín**, ảnh hưởng thái độ và giá; nhiệm vụ thay đổi uy tín |
| Nhiệm vụ | Mạch chính ngắn (mở đầu → boss) + 5–8 nhiệm vụ phụ + bảng nhiệm vụ |
| Chết | Rơi túi tại chỗ, hồi sinh ở nhà |
| Lưu game | Đầy đủ cho mọi hệ thống trên |
| UI | HUD, túi đồ, nhân vật/trang phục, chế tạo, nâng cấp nhà, hội thoại, nhiệm vụ, bản đồ đơn giản, menu chính, cài đặt |
| Âm thanh | Nhạc nền 2–3 bài, SFX cơ bản |

**Ngoài phạm vi luận văn** (làm sau): xây dựng tự do, mùa vụ, câu cá, thú cưng, hôn nhân, multiplayer, thành bang lớn, xung đột phe phức tạp, sprite gameplay đổi theo mọi món trang phục, nhiều vùng hơn.

## 6. Lộ trình (10/2026 → 10/2027)

| Mốc | Thời gian | Nội dung | Kết quả kiểm chứng |
|---|---|---|---|
| **M1 — Nền tảng dữ liệu** ✅ | 10/2026 | Item, túi đồ, rương, nhặt đồ, Save/Load | Xong |
| **M2 — Thời gian & sinh tồn** ✅ | 11/2026 (xong 10/2026) | Đồng hồ, ngày/đêm, **tầm nhìn đêm + đèn**, đói, mana/stamina/né, ngủ (giường + **lều**), **chết rơi túi + hồi sinh** | Sống sót qua một ngày một đêm |
| **M3 — Khởi đầu & class** | 12/2026–01/2027 | **Đấm tay không**, map **Làng**, hội thoại cơ bản, NPC dạy nghề, NPC đổi class (tiền + cooldown), **tiền tệ**, Kiếm sĩ + Pháp sư hoàn chỉnh, prologue | Tỉnh dậy trong rừng → vào làng → học class |
| **M4 — Lượm nhặt, săn & chế tạo** | 02–03/2027 | Công cụ, node tài nguyên, thú săn, công thức, trạm chế tạo, **trang phục có chỉ số**, chợ mua bán | Săn thú → nấu ăn; khai thác → chế vũ khí/áo |
| **M5 — Nhà & trồng trọt** | 04/2027 | Nhà tàn tạ + nâng cấp bằng tiền, vườn, cây trồng | Sửa nhà, trồng → thu hoạch |
| **M6 — Quái, phe phái & thế giới** | 05–06/2027 | Sprite quái + tìm đường, **quái đêm**, loot, **hệ thống uy tín phe**, vùng nguy hiểm, boss | Đánh boss; giết quái phe X làm phe X ghét |
| **M7 — NPC, nhiệm vụ & đồng đội** | 06–07/2027 | Lịch NPC, thân thiết, quà, nhiệm vụ + bảng nhiệm vụ, **NPC đồng đội**, thu hoạch hộ, mạch chính | Chơi trọn mạch chính có đồng đội |
| **M8 — Nhân vật & trang phục** | 08/2027 | **Menu nhân vật "hình dạng thật"**, thay trang phục; Sát thủ/Cung thủ nếu kịp | Thay đồ thấy ngay trên nhân vật |
| **M9 — Hoàn thiện & báo cáo** | 09–10/2027 | Cân bằng, âm thanh, sửa lỗi, hiệu năng, viết luận văn, slide | Bản build demo + báo cáo |

Song song (do chủ dự án tự làm art, không chiếm mốc code): model/art nhân vật "hình dạng thật", sprite quái, icon item, art nhà các cấp, map Làng.

Nguyên tắc: mỗi mốc kết thúc phải **chơi được**. Trễ thì **cắt nội dung** (Sát thủ/Cung thủ, số NPC, số nhiệm vụ), không cắt chất lượng.

## 7. Vấn đề kỹ thuật (gợi ý trình bày trong luận văn)

1. **Kiến trúc data-driven + composition:** item, recipe, crop, class, NPC, quest, faction đều là Resource. Thêm nội dung không cần sửa code.
2. **Hệ thống lưu game:** tách dữ liệu thiết kế / trạng thái người chơi, ID ổn định, migration giữa các phiên bản save.
3. **Isometric + elevation nhiều tầng:** sắp xếp vẽ, collision theo tầng, combat trên mặt phẳng đất.
4. **Pipeline art tự động:** model 3D → Mixamo → render Blender → sprite sheet + manifest. Mở rộng: render nhiều lớp cho trang phục.
5. **Hai lớp hiển thị nhân vật:** sprite gameplay nhỏ (hiệu năng) và **"hình dạng thật"** chi tiết trong menu (3D trong SubViewport hoặc tranh 2D nhiều lớp), cùng dữ liệu trang bị.
6. **Mô phỏng theo thời gian:** cây lớn, node mọc lại, lịch NPC, cooldown đổi class chạy theo đồng hồ game, tính bù khi load vùng.
7. **Tầm nhìn đêm:** bóng tối theo bán kính + nguồn sáng động trên renderer Compatibility.
8. **AI:** state machine quái/NPC, tìm đường nhiều tầng, đồng đội theo sau và chọn mục tiêu, thái độ theo uy tín phe.
9. **Kiểm thử tự động** gameplay, gồm test qua input giả lập.

## 8. Câu hỏi mở [Chưa quyết định]

- Tên thế giới, tên làng, cốt truyện chi tiết, ai đứng sau cuộc tấn công.
- Thế giới liền mạch hay map nối qua cổng.
- Học class đầu tiên có tốn tiền không; giá và cooldown đổi class.
- Vũ khí ngoài class có trang bị được không.
- Chết: trang bị đang mặc có rơi không; túi rơi có biến mất không.
- Đèn có tốn dầu không. Ngủ lều có rủi ro không.
- Nâng cấp nhà chỉ tốn tiền hay cả nguyên liệu.
- Phe phái có xung đột lẫn nhau không.
- Sprite gameplay đổi theo trang phục ở mức nào.
- Phong cách "hình dạng thật" của nhân vật (xem mục 7.5).
