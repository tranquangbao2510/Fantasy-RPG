# Quy tắc cộng tác cho AI agent

Áp dụng cho mọi agent (Claude Code, Codex CLI, Google Antigravity, ...) làm việc trên repository này.

## Ngôn ngữ

- Giao tiếp với người dùng bằng **tiếng Việt**.

## Phạm vi

- Chỉ làm những gì task yêu cầu. Không tự chuyển sang task tiếp theo.
- Không chỉnh sửa module ngoài phạm vi task.
- Không tự ý thêm gameplay hoặc nội dung.
- Không tự ý tạo class nhân vật, skill, NPC, enemy, item hoặc cốt truyện.
- Không triển khai trước những hệ thống chưa được yêu cầu.

## Kiến trúc

- Không thay đổi kiến trúc trong [architecture.md](architecture.md) khi chưa được người dùng cho phép.
- Ưu tiên module độc lập, giao tiếp qua public API và signal.
- Không dùng manager toàn cục tràn lan; không thêm Autoload khi chưa được đồng ý.
- Không tạo script, class, thư mục rỗng chỉ để lấp cấu trúc.
- Ưu tiên giải pháp đơn giản, dễ bảo trì; không overengineering.
- GDScript luôn dùng static typing.

## Dependency

- Không thêm plugin, addon, dependency hay asset bên ngoài khi chưa cần và chưa được đồng ý.
- Không nâng cấp hoặc đổi phiên bản Godot (4.7.2).
- Không thay đổi cấu hình hệ thống hoặc cài đặt phần mềm trên máy.

## Git và file

- **Trước khi bắt đầu mọi task: `git fetch` + `git pull`** (merge, không rebase lịch sử đã push) và kiểm tra `git status` không bị diverged với `origin`. Nếu origin có commit lạ (không do mình biết trước) thì báo người dùng trước khi làm.
- Không xóa file của người dùng; bảo toàn thay đổi chưa commit.
- Không thực hiện thao tác Git phá hủy (reset --hard, force push, ...).
- Không commit, tạo remote hoặc push khi chưa được yêu cầu.
- Commit dưới danh tính Git của người dùng; **không** thêm `Co-Authored-By` hay dòng attribution của AI agent.
- Commit message theo [git_conventions.md](git_conventions.md).

## Kiểm thử

- Mỗi task phải được kiểm tra trong phạm vi phù hợp với thay đổi.
- Không chạy build hoặc test lặp lại khi không có thay đổi liên quan.
- Báo cáo trung thực: nếu không kiểm thử được (thiếu executable, lỗi môi trường), nói rõ thay vì tuyên bố thành công.
- Test đi qua **đường input thật** khi có thể (gửi `InputEventAction` qua `Input.parse_input_event` để node xử lý trong `_input` / `_unhandled_input`), không gọi thẳng hàm mà phím đó kích hoạt. Gọi thẳng chỉ dùng cho logic thuần không có đường input.
- Test kế thừa `tests/test_base.gd`: test **FAIL** khi có lỗi runtime / `push_error` / lỗi biên dịch script nạp lúc chạy mà không khai báo trước bằng `expect_error()` (cảnh báo không tính). Lỗi cố ý (vd. thử file save hỏng) phải khai báo bằng `expect_error()`.
- Chạy toàn bộ test bằng `tests/run_all.gd` (mỗi test một tiến trình; fail khi mã thoát ≠ 0 hoặc thiếu dòng `RESULT`) trước khi báo hoàn thành.
