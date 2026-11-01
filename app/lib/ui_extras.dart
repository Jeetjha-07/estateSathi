import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'theme.dart';

/// Field ke upar label (reference design jaisa)
Widget labeled(String label, Widget child, {bool required = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(
          text: label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
          children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: kRed))
          ],
        )),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

Widget dropdownField(
    String value, List<String> items, ValueChanged<String?> onChanged) {
  return DropdownButtonFormField<String>(
    value: items.contains(value) ? value : items.first,
    items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
    onChanged: onChanged,
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
    decoration: const InputDecoration(),
  );
}

class TabsRow extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const TabsRow(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: i == index ? kPrimary : Colors.transparent,
                            width: 2.5)),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            i == index ? FontWeight.w700 : FontWeight.w500,
                        color: i == index ? kPrimary : kGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PhotoBox extends StatelessWidget {
  final XFile? file;
  final String? existing;
  final String label;
  final double height;
  final double? width;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const PhotoBox({
    super.key,
    this.file,
    this.existing,
    required this.label,
    this.height = 110,
    this.width,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final f = file;
    final e = existing;
    Widget content;
    if (f != null) {
      content = FutureBuilder<Uint8List>(
        future: f.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Icon(Icons.broken_image_rounded, color: kGrey);
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          return Image.memory(snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity);
        },
      );
    } else if (e != null && e.isNotEmpty) {
      content = Image.network(Api.fileUrl(e),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_rounded, color: kGrey));
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_rounded,
              color: kGrey.withAlpha(200), size: 28),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: kGrey)),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: height,
            width: width ?? double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: kPrimary.withAlpha(12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kLine),
            ),
            child: content,
          ),
          if (f != null && onClear != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onClear,
                child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: kInk,
                    child: Icon(Icons.close_rounded,
                        size: 14, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
