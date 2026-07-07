import 'package:flutter/material.dart';
import 'asset_serial_ui.dart';
import 'asset_serial_index_screen.dart';
import 'asset_serial_tag_screen.dart';
import 'asset_serial_lookup_screen.dart';

class AssetSerialHubScreen extends StatelessWidget {
  const AssetSerialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AssetSerialTheme.surface,
      appBar: assetSerialAppBar(context, 'Asset Serial'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AssetSerialTheme.headerGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AssetSerialTheme.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 32),
                SizedBox(height: 12),
                Text('Pelacakan Unit Fisik', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(
                  'Kelola nomor seri asset per unit dengan NFC NTAG di Android.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          assetSerialMenuTile(
            icon: Icons.nfc_rounded,
            title: 'Tag Stok NFC',
            subtitle: 'Daftarkan nomor seri ke sticker NTAG untuk stok lama atau unit baru',
            color: AssetSerialTheme.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetSerialTagScreen())),
          ),
          const SizedBox(height: 12),
          assetSerialMenuTile(
            icon: Icons.sensors_rounded,
            title: 'Scan & Cari',
            subtitle: 'Baca tag NFC atau cari nomor seri secara manual',
            color: const Color(0xFF2563EB),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetSerialLookupScreen())),
          ),
          const SizedBox(height: 12),
          assetSerialMenuTile(
            icon: Icons.inventory_2_outlined,
            title: 'Daftar Nomor Seri',
            subtitle: 'Lihat, detail, dan hapus nomor seri terdaftar',
            color: const Color(0xFFD97706),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetSerialIndexScreen())),
          ),
          const SizedBox(height: 16),
          assetSerialCard(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Format tag: YM:ASSET:{nomor seri}\nWrite NFC hanya didukung di Android.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
