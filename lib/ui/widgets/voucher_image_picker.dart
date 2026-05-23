import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:accounting_app/data/storage_service.dart';

/// Widget for picking/displaying images attached to a voucher.
///
/// Usage:
///   - Pass [voucherId] when editing a saved voucher (images load automatically).
///   - Pass [pendingImages] list when creating a new voucher (collect picked
///     paths before save, then persist after save via [saveAllPending]).
class VoucherImagePicker extends StatefulWidget {
  final int? voucherId;
  final List<String> pendingImages; // used for new (unsaved) vouchers

  const VoucherImagePicker({
    Key? key,
    this.voucherId,
    required this.pendingImages,
  }) : super(key: key);

  @override
  State<VoucherImagePicker> createState() => _VoucherImagePickerState();

  /// Call after saving a new voucher to persist pending images.
  static Future<void> saveAllPending(int voucherId, List<String> pendingImages) async {
    for (final path in pendingImages) {
      await StorageService.saveVoucherImage(voucherId, path);
    }
    pendingImages.clear();
  }
}

class _VoucherImagePickerState extends State<VoucherImagePicker> {
  final ImagePicker _picker = ImagePicker();
  List<String> _savedImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.voucherId != null) {
      _loadSavedImages();
    }
  }

  Future<void> _loadSavedImages() async {
    final images = await StorageService.getVoucherImages(widget.voucherId!);
    setState(() => _savedImages = images);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    // Copy to app documents directory for persistence
    final dir = await getApplicationDocumentsDirectory();
    final filename = 'voucher_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(dir.path, 'voucher_images', filename);
    await Directory(p.dirname(destPath)).create(recursive: true);
    await File(picked.path).copy(destPath);

    if (widget.voucherId != null) {
      // Saved voucher — persist immediately
      await StorageService.saveVoucherImage(widget.voucherId!, destPath);
      await _loadSavedImages();
    } else {
      // New voucher — hold in pending list
      setState(() => widget.pendingImages.add(destPath));
    }
  }

  Future<void> _deleteImage(String path, {bool isPending = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text('This image will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try { await File(path).delete(); } catch (_) {}

    if (isPending) {
      setState(() => widget.pendingImages.remove(path));
    } else if (widget.voucherId != null) {
      await StorageService.deleteVoucherImage(widget.voucherId!, path);
      await _loadSavedImages();
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2C5545)),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2C5545)),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewImage(String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
      ),
    ));
  }

  List<String> get _allImages => [
    ..._savedImages,
    ...widget.pendingImages,
  ];

  @override
  Widget build(BuildContext context) {
    final images = _allImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5545),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showPickOptions,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2C5545),
              ),
            ),
          ],
        ),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No attachments',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          )
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final imgPath = images[index];
                final isPending = widget.pendingImages.contains(imgPath);
                return GestureDetector(
                  onTap: () => _viewImage(imgPath),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imgPath),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _deleteImage(imgPath, isPending: isPending),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
