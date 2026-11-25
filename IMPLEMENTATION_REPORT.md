# Báo cáo thay đổi Vocap

## Đã thực hiện trong lượt này

- Đã bỏ UI và luồng repository của thiết lập Admin lần đầu. Người chưa đăng nhập sẽ đi thẳng tới màn hình đăng nhập/đăng ký.
- Khởi tạo database hiển thị loading ngay; lỗi hoặc timeout có màn hình thông báo và nút thử lại.
- Thêm seeder idempotent cho 1 Admin và 3 User theo thông tin ở README. Seeder không ghi đè tài khoản hiện có và chỉ tính hash cho account còn thiếu.
- Mật khẩu được lưu bằng PBKDF2-HMAC-SHA256 với salt riêng; mật khẩu mẫu không được lưu plaintext.
- Cập nhật test fixture và test migration để dùng tài khoản mặc định.

## Kiến trúc và giới hạn

- App Flutter dùng SQLite cục bộ trên Android và adapter SQLite Web. Runtime Web đã được kiểm chứng tại `localhost:60197`: mở database, chạy migration/seed, đăng nhập tài khoản Admin mặc định và tải lại trang vẫn giữ session/dữ liệu. Một origin kiểm thử riêng cũng xác nhận tài khoản được tạo qua CRUD vẫn tồn tại sau reload.
- Nguyên nhân timeout Web: database đã mở thành công, nhưng seeder tiếp tục tính PBKDF2 120.000 vòng cho bốn tài khoản mặc định bằng Dart thuần trên UI isolate. Trên Web thao tác này chặn frame và vượt timeout 30 giây. Không phải lỗi IndexedDB, WASM hay worker.
- Đã dùng WebCrypto `SubtleCrypto` cho PBKDF2 trên Web, giữ nguyên PBKDF2-HMAC-SHA256, salt và định dạng hash; Android tiếp tục dùng triển khai Dart hiện có. Thêm `web` dependency cùng conditional implementation/stub. Thêm log giai đoạn khởi tạo không chứa thông tin nhạy cảm để quan sát startup.
- Mã nguồn PHP còn trong `backend/`. Yêu cầu xóa thư mục đã bị automatic approval review từ chối; không có thao tác xóa nào được thực hiện.
- Nội dung seed hiện có chưa đạt mục tiêu 200 từ và 10 bộ quiz x 10 câu. Không đánh dấu hoàn tất yêu cầu dữ liệu mẫu này.
- Mật khẩu mẫu có sẵn là thông tin công khai, cần đổi khi sử dụng. SQLite offline không cung cấp ranh giới bảo mật phía server.

## Kiểm thử

- `flutter clean`: PASS.
- `flutter pub get`: PASS.
- `dart format .`: PASS, 41 files.
- `flutter analyze`: PASS, không có vấn đề phân tích.
- `flutter test`: PASS, 8 tests.
- `flutter build web --release`: PASS. Có cảnh báo WebAssembly từ `flutter_tts`; build Web tiêu chuẩn hoàn tất.
- `flutter build apk --debug`: PASS. Có cảnh báo tương thích tương lai cho Gradle/AGP/Kotlin; APK build hoàn tất.
- Browser runtime: PASS. `localhost:60197` khởi tạo SQLite, đăng nhập Admin và tải lại trang thành công; origin kiểm thử riêng xác nhận CRUD persistence qua reload. Thời gian seeding hash của bốn account giảm xuống khoảng 20 ms mỗi hash (từ timeout >30 giây).
- Android database không bị xóa hoặc reset. Debug APK build thành công; database Android runtime không được xóa/gỡ cài đặt trong lượt kiểm tra này.

## Git

Workspace hiện không có `.git`, nên không thể đối chiếu Git diff hoặc khôi phục từ lịch sử.
