# Quy ước Git

Áp dụng cho mọi commit trong repository này, kể cả commit do AI agent tạo.

## Tác giả commit

- Commit dưới danh tính Git của người dùng (`user.name` / `user.email` đã cấu hình). Không đổi tác giả.
- **Không** thêm dòng `Co-Authored-By`, `Generated with ...` hay bất kỳ dòng ghi công/attribution nào cho AI agent trong commit message hoặc PR.
- Chỉ commit / push khi người dùng yêu cầu. Không force push lên `main` khi đã có lịch sử trên remote.

## Cấu trúc commit message

Theo [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <summary>

- <thay đổi chính 1>
- <thay đổi chính 2>

Task: TASK-NN
```

| Phần | Quy tắc |
|---|---|
| `type` | `feat` (tính năng), `fix` (sửa lỗi), `refactor`, `docs`, `test`, `chore` (cấu hình, công cụ, khởi tạo) |
| `scope` | Module/khu vực chính bị ảnh hưởng: `project`, `world`, `map`, `player`, `camera`, `interaction`, `ui`, `git`, ... |
| `summary` | Tiếng Anh, thể mệnh lệnh, chữ thường đầu câu, không dấu chấm cuối, ≤ 72 ký tự |
| Body | Danh sách gạch đầu dòng các thay đổi chính; bỏ qua nếu commit rất nhỏ |
| Footer `Task:` | Mã task tương ứng (`TASK-01`, `TASK-06`, ...). Bỏ qua nếu commit không thuộc task nào |

Mỗi task là một commit (trừ khi người dùng yêu cầu khác). Không gộp thay đổi ngoài phạm vi task vào commit của task; nếu có (vd. Godot Editor lưu lại file), ghi rõ trong body.

## Ví dụ

```
feat(interaction): add interaction system with test objects and UI

- Interactable base class and InteractionDetector component
- Notice board, chest and crystal test objects
- Interaction prompt and feedback UI on a CanvasLayer

Task: TASK-06
```
