# Game Design — Fantasy RPG

> Tài liệu định hướng thiết kế. **Mọi task mới phải đọc file này trước** để biết hệ thống đang làm phục vụ mục tiêu gì.
> Trạng thái: bản nháp v0.1 (2026-10-19). Mục **[Chưa quyết định]** chưa được chốt, không tự chọn thay chủ dự án.

---

## 1. Tóm tắt

Action RPG 2D isometric, đồ họa vẽ tay. Người chơi là **một nhà mạo hiểm** sống ở một ngôi nhà nhỏ giữa thế giới mở. Hằng ngày:
- ra ngoài khám phá, đánh quái, lượm nhặt tài nguyên;
- về nhà trồng trọt, chế tạo, nâng cấp trang bị;
- dần xây dựng quan hệ với cư dân xung quanh.

Game chơi dài, không có điểm kết thúc cứng. Có mạch nhiệm vụ chính dẫn dắt người chơi mở rộng thế giới.

- **Nền tảng:** Windows desktop (chính), Web (phụ)
- **Engine:** Godot 4.7.2, GDScript, Compatibility renderer (xem `docs/architecture.md`)
- **Mục đích hiện tại:** luận văn tốt nghiệp ngành Kỹ thuật Phần mềm. Bảo vệ khoảng 10/2027.

## 2. Trụ cột thiết kế (Design Pillars)

Mọi tính năng mới phải phục vụ ít nhất một trụ cột. Không phục vụ trụ cột nào thì không làm.

1. **Phiêu lưu có thưởng.** Đi đâu cũng có thứ để tìm: tài nguyên, rương, quái mạnh, NPC, lối đi bí mật. Khám phá luôn được đền đáp.
2. **Chiến đấu hành động có chiều sâu.** Combo theo vũ khí, kỹ năng nhiều cách cast, class/mastery. Người chơi giỏi thì đánh khác người chơi mới.
3. **Một mái nhà để quay về.** Nhà là trung tâm: cất đồ, trồng trọt, chế tạo, nghỉ ngơi. Mỗi chuyến đi đều mang về thứ làm nhà và nhân vật mạnh lên.
4. **Một thế giới sống.** NPC có lịch sinh hoạt, có tính cách, nhớ người chơi đã làm gì cho họ. Ngày/đêm thay đổi cách thế giới vận hành.

## 3. Vòng lặp chơi (Core Loops)

### 3.1 Vòng lặp ngày (5–15 phút)

```
Thức dậy ở nhà
  → kiểm tra vườn (tưới, thu hoạch)
  → chế tạo / nấu ăn / sửa trang bị
  → ra ngoài: khám phá, đánh quái, lượm tài nguyên, làm nhiệm vụ, gặp NPC
  → (đói / mệt / trời tối) → quay về nhà
  → cất đồ, ngủ → sang ngày mới
```

### 3.2 Vòng lặp tiến triển (nhiều ngày)

```
Tài nguyên + loot → chế tạo trang bị tốt hơn → vào được vùng nguy hiểm hơn
  → tài nguyên hiếm hơn, quái mạnh hơn → mở công thức mới / kỹ năng mới
Nhiệm vụ + quà tặng → thân thiết NPC → mở cửa hàng, công thức, nhiệm vụ, phần thưởng riêng
```

### 3.3 Thua / chết

Hết HP thì ngất, tỉnh lại ở nhà. Mất một phần đồ trong túi (không mất trang bị đang mặc) và thời gian trôi tới sáng hôm sau. **[Chưa quyết định]** Tỉ lệ mất đồ, có rơi lại tại chỗ để quay lại nhặt không.

## 4. Hệ thống

Ký hiệu trạng thái: ✅ đã có (prototype) · 🟡 có một phần · ⬜ chưa có.

### 4.1 Thế giới & khám phá ⬜🟡
- Thế giới gồm nhiều **vùng** (rừng, tàn tích, hang, bờ hồ, núi...), nối liền nhau. Mỗi vùng có quái, tài nguyên, NPC riêng.
- Góc nhìn isometric 2:1, elevation nhiều tầng, đồ họa vẽ tay (xem `docs/visual/environment-style-guide.md`). ✅
- **Load vùng:** chia thế giới thành vùng/chunk, load/unload theo vị trí người chơi, không màn hình loading khi đi bộ qua ranh giới. **[Chưa quyết định]** Có tách thành các map rời nối bằng cổng/cửa không (dễ làm hơn).
- Điểm đáng chú ý: rương, điểm tài nguyên, lối tắt mở bằng công cụ, điểm dịch chuyển nhanh (mở dần).

### 4.2 Chiến đấu ✅🟡
- Đã có: combo theo vũ khí, 4 ô kỹ năng (Normal/Quick/Instant), class/mastery/passive, tiến hóa kỹ năng, combat trên mặt phẳng iso, lọc theo tầng.
- Cần thêm: **mana** (kỹ năng) và **stamina** (né, chạy, đánh nặng), **né (dodge)**, quái có sprite thật + tìm đường, boss.

### 4.3 Chỉ số sinh tồn ⬜
- **Đói (Hunger):** giảm dần theo thời gian, nhanh hơn khi chạy/đánh. Thấp thì không hồi stamina, cạn thì mất HP chậm.
- **Thể lực/Mệt (Energy):** giảm khi hoạt động, hồi khi ngủ. Thấp thì giảm tốc độ, giảm sát thương.
- Ăn uống hồi chỉ số. Món nấu (chế tạo) hồi nhiều hơn và có buff tạm thời.
- **Không** có khát, nhiệt độ, bệnh trong phạm vi luận văn.

### 4.4 Lượm nhặt (Gathering) ⬜
- Node tài nguyên trong thế giới: cây (gỗ), đá/quặng (đá, khoáng), bụi (quả, thảo dược), nước, ...
- Cần **công cụ** phù hợp (rìu, cuốc chim, liềm). Công cụ có cấp, cấp cao khai thác được node hiếm.
- Node **mọc lại** sau N ngày.
- Quái rơi nguyên liệu (da, xương, ...).

### 4.5 Trồng trọt (Farming) ⬜
- Mảnh vườn cạnh nhà, số ô cố định (mở rộng được qua nâng cấp).
- Quy trình: cuốc đất → gieo hạt → tưới mỗi ngày → lớn theo **ngày trong game** → thu hoạch.
- Mỗi cây có số ngày lớn, mùa vụ **[Chưa quyết định: có mùa không]**, sản lượng.
- Nông sản dùng để ăn, nấu, tặng NPC, bán.

### 4.6 Chế tạo (Crafting) ⬜
- Trạm chế tạo đặt sẵn trong nhà: **bàn chế tạo** (công cụ, vũ khí, trang phục), **bếp** (đồ ăn), **bàn thuốc** (thuốc hồi phục, buff).
- Công thức (recipe) dạng dữ liệu `.tres`: nguyên liệu → sản phẩm, yêu cầu trạm, yêu cầu mở khóa.
- Mở khóa công thức qua: nhặt sách/bản vẽ, NPC dạy, lên cấp mastery.

### 4.7 Túi đồ, trang bị & sưu tầm ⬜
- **Inventory** dạng ô có giới hạn, vật phẩm chồng (stack) được. **Rương** ở nhà để cất.
- **Trang bị:** vũ khí (đã có data vũ khí ✅), mũ, áo, quần, giày, phụ kiện. Mỗi món có chỉ số.
- **Sưu tầm:** sổ tay (codex) ghi lại vũ khí/trang phục/quái/cây trồng đã gặp. Đây là động lực khám phá.
- **Ngoại hình:** trang phục đổi ngoại hình nhân vật. **[Kỹ thuật cần giải]** Sprite nhân vật hiện render sẵn từ 3D (CHAR-01). Đổi trang phục cần render nhiều lớp (thân, áo, quần, vũ khí) chồng lên nhau, xem mục 7.

### 4.8 Nhà ⬜
- Nhà **có sẵn**, không xây tự do. Bên trong: giường (ngủ/lưu game), rương, các trạm chế tạo, vườn bên ngoài.
- Nâng cấp nhà bằng tài nguyên: mở thêm trạm, mở rộng vườn, thêm rương. **[Chưa quyết định]** Có trang trí nội thất không.

### 4.9 NPC & quan hệ ⬜
- Mỗi NPC: tên, tính cách, nơi ở, **lịch sinh hoạt theo giờ**, sở thích (quà thích/ghét).
- **Độ thân thiết** (0–10 tim hoặc tương đương): tăng khi nói chuyện mỗi ngày, tặng quà, làm nhiệm vụ cho họ.
- Mốc thân thiết mở: hội thoại mới, cửa hàng giảm giá, công thức, nhiệm vụ riêng, vật phẩm độc nhất.
- Hội thoại dạng dữ liệu (cây hội thoại có điều kiện: độ thân thiết, nhiệm vụ, thời gian).

### 4.10 Nhiệm vụ ⬜
- Loại: thu thập, tiêu diệt, giao hàng, nói chuyện, khám phá địa điểm.
- **Mạch chính:** dẫn người chơi mở từng vùng mới. **Nhiệm vụ phụ:** từ NPC, gắn với quan hệ.
- Sổ nhiệm vụ (quest log), đánh dấu mục tiêu.

### 4.11 Thời gian & ngày/đêm ⬜
- Đồng hồ trong game (ví dụ 1 ngày = 15–20 phút thực, **[Chưa quyết định]**).
- Ngày/đêm đổi ánh sáng, đổi quái (ban đêm nguy hiểm hơn), đổi lịch NPC.
- Cây trồng, node tài nguyên, cửa hàng dựa vào ngày.

### 4.12 Lưu game ⬜
- Lưu khi ngủ ở giường (và autosave khi thoát). Lưu: vị trí, chỉ số, túi đồ, rương, trang bị, class/kỹ năng, vườn, node đã khai thác, NPC, nhiệm vụ, thời gian.
- **Quy tắc kỹ thuật cho mọi hệ thống từ giờ:** dữ liệu người chơi tách khỏi dữ liệu thiết kế (`.tres` chỉ đọc), mọi thứ cần lưu có **ID ổn định** (string), không lưu đường dẫn node.

### 4.13 Kinh tế ⬜
- Tiền tệ (vàng), mua bán ở cửa hàng NPC. Bán nông sản, nguyên liệu, đồ thừa.

## 5. Phạm vi luận văn (MVP — mục tiêu tới ~08/2027)

Mỗi hệ thống có **một bản nhỏ nhưng chạy thật**, nối thành vòng lặp ngày hoàn chỉnh. Ưu tiên **chạy được, có test, có docs** hơn nhiều nội dung.

| Hệ thống | Nội dung tối thiểu cho luận văn |
|---|---|
| Thế giới | **3 vùng**: Làng/Nhà (an toàn), Rừng Glade (đã có), Tàn tích/Hang (nguy hiểm). Đi liền mạch hoặc qua cổng |
| Chiến đấu | Đã có + mana/stamina + né. **4 loại quái** (2 thường, 1 tầm xa, 1 tinh anh) có sprite + tìm đường. **1 boss** |
| Sinh tồn | Đói + thể lực, ăn uống, ngủ hồi phục |
| Lượm nhặt | 3 công cụ (rìu, cuốc chim, liềm), ~8 loại tài nguyên, node mọc lại |
| Trồng trọt | 6–9 ô vườn, **4 loại cây**, tưới, lớn theo ngày |
| Chế tạo | 3 trạm (bàn chế tạo, bếp, bàn thuốc), **~20 công thức** |
| Túi đồ/trang bị | Inventory + 1 rương + trang bị vũ khí và **2 slot trang phục** (áo, mũ) có chỉ số |
| Nhà | Nhà có sẵn: giường, rương, 3 trạm, vườn |
| NPC | **3 NPC** có lịch sinh hoạt, hội thoại, độ thân thiết, quà thích/ghét. 1 người bán hàng |
| Nhiệm vụ | Mạch chính ngắn (3–4 bước, kết thúc bằng boss) + 3–5 nhiệm vụ phụ |
| Thời gian | Đồng hồ + ngày/đêm (ánh sáng + quái đêm) |
| Lưu game | Save/Load đầy đủ, 1–3 slot |
| UI | HUD (HP/mana/stamina/đói/giờ), túi đồ, chế tạo, hội thoại, sổ nhiệm vụ, menu chính, cài đặt cơ bản |
| Âm thanh | Nhạc nền 2–3 bài, SFX cơ bản (đánh, nhặt, bước chân) |

**Ngoài phạm vi luận văn** (làm sau): xây dựng tự do, mùa vụ, câu cá, thú cưng, hôn nhân, multiplayer, nhiều vùng hơn, trang trí nhà, đổi ngoại hình theo trang phục (nếu chưa kịp).

## 6. Lộ trình đề xuất (11/2026 → 10/2027)

| Mốc | Thời gian | Nội dung | Kết quả kiểm chứng |
|---|---|---|---|
| **M1 — Nền tảng dữ liệu** | 11–12/2026 | Item database (ID, loại, stack, icon), Inventory + UI, nhặt vật phẩm, rương, **khung Save/Load** (lưu vị trí + túi đồ) | Nhặt đồ, cất rương, thoát game vào lại còn nguyên |
| **M2 — Thời gian & sinh tồn** | 01–02/2027 | Đồng hồ, ngày/đêm, ngủ, đói/thể lực, ăn uống, mana/stamina + né | Một ngày chơi trọn vẹn: đói → ăn, tối → ngủ |
| **M3 — Lượm nhặt & chế tạo** | 03–04/2027 | Công cụ, node tài nguyên + mọc lại, công thức, 3 trạm chế tạo, trang bị trang phục | Chặt cây → chế rìu tốt hơn → khai thác quặng → chế vũ khí |
| **M4 — Nhà & trồng trọt** | 05/2027 | Map làng/nhà, vườn, 4 loại cây, nâng cấp nhà cơ bản | Gieo → tưới → thu hoạch → nấu ăn |
| **M5 — Quái & thế giới** | 06–07/2027 | Sprite quái (pipeline 3D → 2D), tìm đường, loot table, vùng thứ 3, boss | Đánh boss rơi đồ hiếm |
| **M6 — NPC & nhiệm vụ** | 07–08/2027 | Hội thoại, lịch sinh hoạt, thân thiết, quà, cửa hàng, mạch chính + phụ | Chơi trọn mạch chính từ đầu tới boss |
| **M7 — Hoàn thiện & viết báo cáo** | 09–10/2027 | Cân bằng, âm thanh, sửa lỗi, đo hiệu năng, viết luận văn, slide | Bản build demo + báo cáo |

Nguyên tắc: mỗi mốc kết thúc phải **chơi được** (không để hệ thống nằm dở). Trễ thì **cắt nội dung**, không cắt chất lượng.

## 7. Vấn đề kỹ thuật cần giải (gợi ý đề tài nghiên cứu cho luận văn)

Đây là phần "kỹ thuật phần mềm" để trình bày trong luận văn, ngoài phần game:

1. **Kiến trúc data-driven + composition:** item, recipe, crop, NPC, quest đều là Resource; hệ thống chỉ đọc dữ liệu. Thêm nội dung không cần sửa code.
2. **Hệ thống lưu game:** tách dữ liệu thiết kế / trạng thái người chơi, ID ổn định, quản lý phiên bản save (migration khi cấu trúc đổi).
3. **Isometric + elevation nhiều tầng:** sắp xếp vẽ, collision theo tầng, combat trên mặt phẳng đất (đã có VISUAL-02/02.1).
4. **Pipeline sprite 3D → 2D:** model AI → Mixamo → render Blender tự động → sprite sheet + manifest (đã có CHAR-01). Mở rộng: **render nhiều lớp** để đổi trang phục/vũ khí.
5. **Mô phỏng thế giới theo thời gian:** cây lớn, node mọc lại, lịch NPC chạy cả khi người chơi ở vùng khác (tính bù khi load vùng).
6. **AI NPC/quái:** state machine, tìm đường trên map nhiều tầng.
7. **Kiểm thử tự động** cho gameplay (đã có `tests/`), có thể thêm đo hiệu năng.

## 8. Câu hỏi mở [Chưa quyết định]

- Tên thế giới, bối cảnh, mạch truyện chính (nhà mạo hiểm đến đây vì sao?).
- Thế giới liền mạch hay các map nối qua cổng.
- Độ dài 1 ngày trong game; có mùa không.
- Hình phạt khi chết.
- Có đổi ngoại hình theo trang phục trong phạm vi luận văn không.
