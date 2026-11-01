import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'theme.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const StatCard({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyBox(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: kPrimary.withAlpha(90)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kGrey)),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? photo;
  final String name;
  final double size;
  const Avatar({super.key, this.photo, required this.name, this.size = 48});

  Widget _initial() => Container(
        color: kPrimary.withAlpha(30),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: size * 0.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final has = photo != null && photo!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
      child: SizedBox(
        width: size,
        height: size,
        child: has
            ? Image.network(Api.fileUrl(photo), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial())
            : _initial(),
      ),
    );
  }
}

/// Data load karke dikhane wala generic widget (loading / error / retry ke saath)
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final bool standalone; // push ki hui screen ke liye: loading/error me bhi AppBar dikhe
  const Loader({super.key, required this.load, required this.builder, this.standalone = false});

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? data;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget wrap(Widget w) => widget.standalone ? Scaffold(appBar: AppBar(), body: w) : w;
    if (loading && data == null) return wrap(const Center(child: CircularProgressIndicator()));
    if (data == null) {
      return wrap(Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 52, color: kGrey),
              const SizedBox(height: 12),
              Text(error ?? 'Kuch gadbad ho gayi', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => loading = true);
                  reload();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Dobara try karein'),
              ),
            ],
          ),
        ),
      ));
    }
    return widget.builder(context, data as T, reload);
  }
}

void toast(BuildContext c, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? kRed : kInk,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));
}

Future<bool> confirmAction(BuildContext c, String title, String msg, {String okText = 'Delete', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? kRed : kPrimary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return r == true;
}

Future<bool> confirmDelete(BuildContext c, String title, String msg) => confirmAction(c, title, msg);

void showPhoto(BuildContext c, String? path) {
  if (path == null || path.isEmpty) return;
  showDialog(
    context: c,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InteractiveViewer(child: Image.network(Api.fileUrl(path))),
      ),
    ),
  );
}

Future<XFile?> pickPhoto(BuildContext c) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: c,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: kPrimary),
            title: const Text('Camera se photo lein'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: kPrimary),
            title: const Text('Gallery se chunein'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (src == null) return null;
  return ImagePicker().pickImage(source: src, imageQuality: 60, maxWidth: 1280);
}


class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'paid':
        return const Pill('Paid', kGreen);
      case 'partial':
        return const Pill('Partial', kAmber);
      default:
        return const Pill('Pending', kRed);
    }
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 26, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.home_work_rounded, color: kGold, size: size + 4),
        const SizedBox(width: 8),
        Text('EstateSathi',
            style: TextStyle(fontSize: size * 0.78, fontWeight: FontWeight.w700, color: light ? Colors.white : kPrimary)),
      ],
    );
  }
}

class PropertyImage extends StatelessWidget {
  final String? photo;
  final double? height;
  const PropertyImage({super.key, this.photo, this.height});

  Widget _placeholder() => Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kPrimary, kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(child: Icon(Icons.apartment_rounded, size: 54, color: Colors.white.withAlpha(110))),
      );

  @override
  Widget build(BuildContext context) {
    if (photo == null || photo!.isEmpty) return _placeholder();
    return Image.network(
      Api.fileUrl(photo),
      fit: BoxFit.cover,
      width: double.infinity,
      height: height,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}

Future<void> editServerUrl(BuildContext c) async {
  final ctl = TextEditingController(text: Api.baseUrl);
  final ok = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Server URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      content: TextField(
        controller: ctl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'http://192.168.1.5:5000'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true) {
    await Api.saveBaseUrl(ctl.text);
    if (c.mounted) toast(c, 'Server URL save ho gaya');
  }
}
