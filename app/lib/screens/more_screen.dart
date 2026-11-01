import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Widget _tile(IconData icon, String title, {String? subtitle, Color color = kPrimary, VoidCallback? onTap}) {
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color == kRed ? kRed : kInk)),
        subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12, color: kGrey)),
        trailing: const Icon(Icons.chevron_right_rounded, color: kGrey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SoftCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Avatar(name: Api.userName, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Api.userName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const Text('Owner account', style: TextStyle(color: kGrey, fontSize: 12)),
                    ],
                  ),
                ),
                const AppLogo(size: 18),
              ],
            ),
          ),
          _tile(Icons.dns_rounded, 'Server URL', subtitle: Api.baseUrl, onTap: () async {
            await editServerUrl(context);
            if (mounted) setState(() {});
          }),
          _tile(Icons.info_outline_rounded, 'EstateSathi ke baare me', onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'EstateSathi',
              applicationVersion: '1.0.0',
              children: const [Text('Rent owners ke liye kiraya management app.')],
            );
          }),
          _tile(Icons.logout_rounded, 'Logout', color: kRed, onTap: () async {
            if (await confirmAction(context, 'Logout', 'Logout karna hai?', okText: 'Logout', danger: false)) {
              await Api.logout();
              Api.onUnauthorized?.call();
            }
          }),
        ],
      ),
    );
  }
}
