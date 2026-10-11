# An Tiếng Gáy Trong Đêm — bản chơi thử đầu tiên

Vertical slice Godot 4 cho bốn nhịp mở đầu: hành lang và lá thư, lời dẫn trong lớp học, chạy trốn trong nhà vệ sinh, rồi chiếc gương và bóng ma. Hình ảnh là hình học/đồ họa vẽ trực tiếp bằng GDScript; không dùng hình hay âm thanh bên ngoài.

## Chạy

Mở thư mục này bằng Godot 4.x hoặc chạy:

```sh
godot --path . --editor
```

Nhấn **F6/F5** trong editor hoặc chạy scene chính `scenes/01_hanh_lang.tscn`.

## Điều khiển

- **WASD** hoặc **phím mũi tên** — di chuyển.
- **E** — đọc/tiếp tục/tương tác.
- **Esc** — thoát.

Lá thư có vùng tương tác gần tờ giấy giữa hành lang. Ở sự kiện nhà vệ sinh, chạy vào buồng cuối (vùng sáng nhạt bên phải) và nhấn **E** trước khi hết 3 giây. Nếu không kịp, màn hình **YOU DIED** cho phép thử lại.

## Việt hóa phông chữ

Văn bản lưu UTF-8 và dùng phông chữ fallback của Godot để tránh phụ thuộc asset ngoài. Cần kiểm tra glyph tiếng Việt trên từng hệ điều hành; để đóng gói ổn định, có thể thêm một phông sans hỗ trợ tiếng Việt với giấy phép OFL (ví dụ Noto Sans), lưu tại `assets/fonts/`, rồi gán làm theme font mặc định trong project. Không có font hay asset bên thứ ba nào được sao chép vào dự án.

## Giới hạn bản slice

Đây là bản dựng câu chuyện tương tác tối giản: chưa có âm thanh, hoạt ảnh, lưu game, hoặc các chương sau. Nhịp cốt truyện và lời thoại là văn bản nguyên bản cho slice này; cần đối chiếu với bản kịch bản 15 cảnh đầy đủ nếu có bản chi tiết bên ngoài repo.
