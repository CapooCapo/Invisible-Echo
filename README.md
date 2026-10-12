# An — Tiếng Gáy Trong Đêm

Game kinh dị học đường Việt Nam, viết bằng GDScript cho Godot 4.7.2. Đêm thứ nhất có 15 cảnh tương tác, sáu kỷ vật, các câu đố, stealth/chase, thử thách cờ vua, lựa chọn có hệ quả, hai kết thúc và cờ mở khóa Đêm thứ hai. Trạng thái hiện tại là **HUMAN_PLAYTEST_REQUIRED**, chưa phải RELEASE_READY.

## Chạy từ mã nguồn

Mở thư mục dự án bằng Godot 4.x hoặc chạy:

```sh
godot --path .
```

Godot khởi chạy từ cảnh mở đầu và tự khôi phục checkpoint đã lưu nếu có. Save JSON được đặt trong `user://an_tieng_gay_trong_dem_save.json`.

## Bản chạy Linux

`tools/build_linux.sh` tạo bản Linux trong `builds/` bằng template release Godot 4.7.2 và một PCK đặt cạnh executable; cần giữ hai file cùng thư mục. Hai preset Linux và Windows trong `export_presets.cfg` cũng đã xuất thành công bằng template Godot 4.7.2 đã xác minh SHA-512. Cặp Linux mới đã smoke-test headless với save QA riêng; full GUI playthrough chưa xác minh. File Windows `.exe` đã xác nhận định dạng PE32+ x86_64 nhưng chưa chạy thử trên Windows. Template, archive và build artifacts được giữ trong `builds/` (bị Git ignore).

## Điều khiển

- **WASD / phím mũi tên** — di chuyển hoặc điều hướng ô.
- **E / Enter** — tương tác, chọn hoặc xác nhận.
- **F** — tạo tiếng động đánh lạc hướng bảo vệ trong cảnh tuần tra.
- **Space** — nấp khi đang ở vùng che khuất.
- **R** — chơi lại/xếp lại câu đố hiện tại.
- **H** — gợi ý mạch điện sau vài lần thử.
- **A / B** — chọn cách xử lý bài đăng ở cảnh 10.
- **X** — xin dừng thử thách cờ vua; E rời bàn hoặc R chơi lại.
- **Esc** — thả chuột khỏi góc nhìn 3D.

## Nội dung

Các scene 01–04 mở đầu bằng lá thư, lớp học, thử thách trốn trong ba giây và chiếc gương. Scenes 05–08 điều tra bảng tin, tủ A-17, nhật ký sáu mảnh, mạch điện 4×4, bảo vệ tuần tra và cuộc truy đuổi. Scenes 09–11 giải mã máy tính, khôi phục camera, cân nhắc lời đồn và ghép chứng cứ. Scenes 12–15 trả lại sáu kỷ vật, đấu một thế cờ chiếu hết hợp lệ, đối diện buổi sáng và mở một trong hai kết thúc.

GameState lưu inventory, flags, chứng cứ, lựa chọn và checkpoint. Luật cờ vua thuần GDScript, không dùng engine bên ngoài. Audio ambience và SFX được tổng hợp riêng cho dự án; các cảnh mở đầu 01–04 dùng model 3D Blender và texture tạo riêng cho dự án, các phần còn lại dùng hình vẽ bằng mã nguồn. Không có tài nguyên bên thứ ba trong bản hiện tại.

## Kiểm tra

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 3
```

Các harness trong `tests/` có thể chạy bằng `godot --headless --path . --script tests/<test>.gd`. Xem `docs/PROGRESS.md` và `docs/TASK_BOARD.md` để biết bằng chứng mới nhất và phần còn chưa xác minh. Báo cáo [Release QA](docs/RELEASE_QA.md) và [hướng dẫn playtest thủ công 15 cảnh](docs/PLAYTEST_HANDOFF.md) ghi profile save riêng, checklist, cách chụp ảnh và mẫu bug report.
