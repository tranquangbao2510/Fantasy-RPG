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

- Không xóa file của người dùng; bảo toàn thay đổi chưa commit.
- Không thực hiện thao tác Git phá hủy (reset --hard, force push, ...).
- Không commit, tạo remote hoặc push khi chưa được yêu cầu.

## Kiểm thử

- Mỗi task phải được kiểm tra trong phạm vi phù hợp với thay đổi.
- Không chạy build hoặc test lặp lại khi không có thay đổi liên quan.
- Báo cáo trung thực: nếu không kiểm thử được (thiếu executable, lỗi môi trường), nói rõ thay vì tuyên bố thành công.
