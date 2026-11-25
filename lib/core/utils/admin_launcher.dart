import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _adminPortalUrl = 'https://vocabgo-c37af.web.app/admin.html';

Future<void> openAdminPortal(BuildContext context) async {
  var opened = false;
  try {
    // Launch immediately from the tap callback so browsers allow the new tab.
    opened = await launchUrl(
      Uri.parse(_adminPortalUrl),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    // Show the direct link if the platform cannot open the portal.
  }

  if (!opened && context.mounted) {
    _showAdminInfoDialog(context);
  }
}

void _showAdminInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            color: Color(0xFF3F6AD8),
            size: 28,
          ),
          SizedBox(width: 10),
          Text(
            'Trang Quản Trị Admin',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trang Quản trị ArchitectUI HTML chính thức đã được tích hợp đầy đủ tính năng Thêm, Sửa, Xóa và Tạo nội dung thông minh trực tiếp trên Cloud Firestore.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3F6AD8).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3F6AD8).withValues(alpha: 0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đường dẫn trang quản trị:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4),
                SelectableText(
                  _adminPortalUrl,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F6AD8),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
