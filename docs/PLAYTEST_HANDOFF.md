# Đêm 1 — hướng dẫn playtest thủ công

Dùng checklist này để hoàn tất các bước không thể suy ra từ harness. Không dùng save chính làm fixture và không đánh dấu mục đạt chỉ vì test code đã chuyển scene.

## Khởi chạy profile QA riêng

Bản Linux gồm hai file phải đặt cạnh nhau: `builds/an-tieng-gay-trong-dem-linux.x86_64` và `builds/an-tieng-gay-trong-dem-linux.pck`. Không tách hoặc đổi tên riêng một file. Trong một terminal, tạo profile mới rồi chạy:

```sh
AN_QA_HOME="$(mktemp -d -t an-night1-qa.XXXXXX)"
mkdir -p "$AN_QA_HOME/data" "$AN_QA_HOME/config"
export XDG_DATA_HOME="$AN_QA_HOME/data"
export XDG_CONFIG_HOME="$AN_QA_HOME/config"
cd /home/giahoang/dev/an-tieng-gay-trong-dem
./builds/an-tieng-gay-trong-dem-linux.x86_64
```

`tools/build_linux.sh` sẽ tạo lại đúng cặp executable + PCK này bằng template Godot 4.7.2 đã kiểm tra version. Bản ghép PCK cũ đã bị thay thế; không dùng artifact cũ để playtest.

Giữ nguyên terminal/profile đó khi đóng rồi chạy lại để kiểm tra load checkpoint. Muốn thử nhánh mới hoặc choice khác, dùng một thư mục `AN_QA_HOME` mới. Game hiện vào thẳng scene 01 và tự khôi phục `user://`; chưa có menu New Game/Continue/Settings.

Save chính hiện nằm ở `~/.local/share/godot/app_userdata/An Tiếng Gáy Trong Đêm/an_tieng_gay_trong_dem_save.json`. Bản sao QA có hậu tố `.pre-release-qa-20261011`; không xóa hoặc ghi đè hai file này trong buổi playtest.

## Điều khiển

- WASD / mũi tên: đi lại hoặc di chuyển ô/cursor.
- E / Enter: tương tác, chọn/xác nhận.
- Space: nấp ở vùng che khuất; F: đánh lạc hướng bảo vệ.
- R: thử/xếp lại câu đố; H: gợi ý mạch điện.
- A / B: choice bài đăng ở scene 10; X: xin dừng chess.
- Esc: thoát.

## Checklist 15 cảnh

Với mỗi mục, ghi **PASS / FAIL / NOT VERIFIED**, profile QA, thao tác đã dùng, và screenshot/log nếu có.

- [ ] **01 — Hành lang:** đi tới lá thư, nhấn E; xác nhận thư hiện ra và chữ tiếng Việt đọc được; nhấn E gấp thư.
- [ ] **02 — Lớp học:** đọc các lá thư và lời nhắn 23:00; nhấn E để bắt đầu đêm.
- [ ] **03 — Nhà vệ sinh / 3 giây:** trong một lần thử, không trốn và xác nhận YOU DIED rồi Retry/E hoạt động. Trong lần khác, chạy sang buồng cuối được đánh sáng bên phải và nhấn E trước khi hết giờ; ghi thời gian/thao tác thực tế.
- [ ] **04 — Gương:** đi tới gương, nhấn E; xác nhận bóng người xuất hiện *bên trong mặt gương*. Nhấn E quay lại, xác nhận phòng trống rồi theo mục tiêu tới bảng tin. Ghi rõ nếu chỉ có lời thoại, không có animation quay đầu.
- [ ] **05 — Bảng tin:** xem ảnh và mặt sau, giải manh mối ngày 18/04 và tủ A-17.
- [ ] **06 — Nhật ký:** thu đủ sáu mảnh, sắp theo trình tự ngày được gợi ý; thử đổi mảnh sai, dùng R nếu cần và nhận kỷ vật khi hoàn tất.
- [ ] **07 — Phòng điện:** xoay các ô mạch 4×4 để nối nguồn tới khóa cầu thang; ghi nhận phản hồi khi tuyến đúng/sai và kiểm tra H.
- [ ] **08 — Tuần tra/truy đuổi:** quan sát vùng nhìn và suspicion; thử Space để nấp, F để nhử; lấy móc khóa và vượt chướng ngại chase.
- [ ] **09 — Phòng máy tính:** nhập 1804, sắp xếp clip camera, xem báo cáo tai nạn và nhận ảnh.
- [ ] **10 — Bài đăng:** đối chiếu bản nháp, thời gian, tài khoản và hội thoại An–Minh. Dùng profile riêng để thử A (đăng nguyên văn) và B (xác minh/cảnh báo); xác nhận choice không bị đổi sau khi ghi.
- [ ] **11 — Bảng chứng cứ:** tự nối đủ ba kết luận; kiểm tra phản hồi khi nối sai và nhận kỷ vật thứ sáu.
- [ ] **12 — Phòng cờ:** đặt trả đủ sáu kỷ vật vào vị trí phù hợp; kiểm tra trùng vật/thiếu vật không mở chess.
- [ ] **13 — Chess:** thử Story, Normal và Challenge riêng; thực hiện nước đi hợp lệ; kiểm tra thua/hòa → retry; dùng X để xác nhận nhánh Bad Ending trong profile riêng; hoàn tất chiếu hết để đi nhánh Good Ending.
- [ ] **14 — Ký ức cuối:** đi qua ba điểm sáng, nhận quân vua đen và kiểm tra lời giải thích có hiện đủ.
- [ ] **15 — Kết thúc:** xác nhận hậu quả đúng theo A/B và Good/Bad Ending; ghi trạng thái Night 2 unlock. Không đánh giá phần truyện Đêm 2 — chưa thuộc phạm vi.

## Save/load và checkpoint

- [ ] Thoát sau một checkpoint đã ghi rõ ở scene 05–15; chạy lại bằng đúng XDG profile; xác nhận scene/checkpoint được khôi phục.
- [ ] Lặp lại bằng profile sạch để chắc rằng New Game không kế thừa inventory/choice cũ.
- [ ] Nếu puzzle chess/evidence board khởi động lại sau reload, ghi nhận đúng hành vi; một số state trung gian hiện không được lưu đầy đủ.
- [ ] Xác nhận Retry sau death và Retry chess không xóa nhầm tiến độ trước checkpoint.

## Chụp ảnh/video

Lưu bằng chứng vào `builds/release-qa/` để không lẫn với source asset. Chỉ chụp cửa sổ game, tránh đưa nội dung desktop/ứng dụng riêng tư vào ảnh. Trên Hyprland/Wayland có thể dùng:

```sh
mkdir -p builds/release-qa
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}" \
  grim -g "$(slurp)" builds/release-qa/scene-NN-description.png
```

Trên X11, focus game rồi chụp cửa sổ đang active:

```sh
import -window "$(xdotool getactivewindow)" builds/release-qa/scene-NN-description.png
```

Tên ảnh nên có số scene và trạng thái, ví dụ `scene03-death.png`, `scene04-mirror-apparition.png`, `scene13-checkmate.png`. Nếu quay video, bắt đầu trước khi vào cảnh và giữ thao tác trong khung hình để phân biệt gameplay thật với scene capture.

## Mẫu báo lỗi

```text
ID / mức độ:
Build + OS + Godot version:
QA profile (không gửi save chính):
Scene / checkpoint / branch / chess mode:
Điều kiện trước khi lỗi:
Bước tái hiện (đánh số, có phím bấm và thời lượng):
Kết quả mong đợi:
Kết quả thực tế:
Tần suất (x/n lần):
Screenshot / video / log:
Save QA có thể chia sẻ? (không đính kèm user save):
```

## Các mục agent không thể tự chốt

- Nghe thử chất lượng, mức âm lượng, độ lặp/đè và cân bằng ambience/SFX bằng tai người.
- Cảm nhận độ công bằng của timer/stealth/chase và khả năng hiểu puzzle mà không đọc source.
- Chạy Windows build trên Windows.
- Quyết định có bổ sung menu/settings, các SFX còn thiếu và animation quay đầu trước khi phát hành thử.
