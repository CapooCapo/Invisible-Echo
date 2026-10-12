# An — Tiếng Gáy Trong Đêm

Game kinh dị học đường Việt Nam, viết bằng GDScript cho Godot 4.7.2. Đêm thứ nhất có 15 cảnh tương tác, sáu kỷ vật, các câu đố, stealth/chase, thử thách cờ vua, lựa chọn có hệ quả, hai kết thúc và cờ mở khóa Đêm thứ hai. Trạng thái hiện tại là **HUMAN_PLAYTEST_REQUIRED**, chưa phải RELEASE_READY.

## Chạy từ mã nguồn

Mở thư mục dự án bằng Godot 4.x hoặc chạy:

```sh
godot --path .
```

Godot khởi chạy từ cảnh mở đầu và tự khôi phục checkpoint đã lưu nếu có. Save JSON được đặt trong `user://an_tieng_gay_trong_dem_save.json`.

## Bản chạy Linux

tools/build_linux.sh tạo bản Linux trong builds/ bằng template release Godot 4.7.2 và một PCK đặt cạnh executable; cần giữ hai file cùng thư mục. Bản xuất Linux/Windows trong docs/RELEASE_QA.md là baseline trước đợt nâng cấp 3D. Bản 3D hiện tại đã được xuất và khởi chạy headless riêng tại builds/visual-qa/final-20261011/; xem docs/VISUAL_QA.md để biết giới hạn xác minh. Windows runtime và chơi thử bản 3D toàn tuyến vẫn chưa được kiểm tra. Template, archive và build artifacts được giữ trong builds/ (bị Git ignore).

## Điều khiển

- **WASD / phím mũi tên** — di chuyển hoặc điều hướng ô.
- **E / Enter** — tương tác, chọn hoặc xác nhận.
- **F** — tạo tiếng động đánh lạc hướng bảo vệ trong cảnh tuần tra.
- **Space** — nấp khi đang ở vùng che khuất.
- **R** — chơi lại/xếp lại câu đố hiện tại.
- **H** — gợi ý mạch điện sau vài lần thử.
- **A / B** — chọn cách xử lý bài đăng ở cảnh 10.
- **X** — xin dừng thử thách cờ vua; E rời bàn hoặc R chơi lại.
- **Esc** — thoát.

## Nội dung

Các scene 01–04 mở đầu bằng lá thư, lớp học, thử thách trốn trong ba giây và chiếc gương. Scenes 05–08 điều tra bảng tin, tủ A-17, nhật ký sáu mảnh, mạch điện 4×4, bảo vệ tuần tra và cuộc truy đuổi. Scenes 09–11 giải mã máy tính, khôi phục camera, cân nhắc lời đồn và ghép chứng cứ. Scenes 12–15 trả lại sáu kỷ vật, đấu một thế cờ chiếu hết hợp lệ, đối diện buổi sáng và mở một trong hai kết thúc.

GameState lưu inventory, flags, chứng cứ, lựa chọn và checkpoint. Luật cờ vua thuần GDScript, không dùng engine bên ngoài. Audio ambience và SFX được tổng hợp riêng cho dự án. **Visual Production đang diễn ra:** các không gian mở đầu, nhà vệ sinh, phòng máy và câu lạc bộ cờ đã có mô hình 3D Godot/GLB gốc, còn nhiều cảnh và hiệu ứng vẫn là 2D. Xem [tiến độ đồ họa](docs/VISUAL_PROGRESS.md) và [bằng chứng runtime](docs/VISUAL_QA.md); các ảnh concept không nằm trong gameplay.

## Kiểm tra

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 3
```

Các harness trong `tests/` có thể chạy bằng `godot --headless --path . --script tests/<test>.gd`. Xem `docs/PROGRESS.md` và `docs/TASK_BOARD.md` để biết bằng chứng mới nhất và phần còn chưa xác minh. Báo cáo [Release QA](docs/RELEASE_QA.md) và [hướng dẫn playtest thủ công 15 cảnh](docs/PLAYTEST_HANDOFF.md) ghi profile save riêng, checklist, cách chụp ảnh và mẫu bug report.
