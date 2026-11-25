# Vocap

Vocap là ứng dụng học từ vựng Flutter chạy trên Android và Web. Firebase Authentication quản lý tài khoản, Firestore lưu nội dung và dữ liệu học tập. Ứng dụng dùng Spark miễn phí; SQLite chỉ còn được dùng làm nguồn nhập dữ liệu cũ trong giai đoạn chuyển đổi.

## Lưu trữ

Firebase được cấu hình cho Android và Web trong project `vocabgo-c37af`. Khi đăng nhập Firebase, ứng dụng tìm tài khoản SQLite cũ cùng email để nhập tiến độ, cài đặt, lịch sử quiz và dữ liệu học tập. Mật khẩu cũ không được sao chép; người dùng cần đăng ký hoặc đặt lại mật khẩu Firebase. Chi tiết triển khai và nhập dữ liệu nằm trong [FIREBASE_MIGRATION.md](FIREBASE_MIGRATION.md).

## Tài khoản ban đầu

Firebase không tạo tài khoản mặc định. Admin đầu tiên phải được cấp Firebase Auth custom claim `admin: true` từ môi trường tin cậy có Firebase Admin SDK. Hồ sơ người dùng trong Firestore không thể tự cấp quyền quản trị.

## Chạy và kiểm tra

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

Firestore rules cần được deploy trước khi sử dụng đăng ký và công cụ quản trị. Trên Spark, quản lý tài khoản Auth được thực hiện trong Firebase Console. Xem [FIREBASE_MIGRATION.md](FIREBASE_MIGRATION.md).
# vocap-app
