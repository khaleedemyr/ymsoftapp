import 'package:flutter/material.dart';
import '../utils/omni_emoji_list.dart';
import '../utils/omni_theme.dart';

/// Picker emoji full-screen sheet — tap selalu berfungsi (tidak tertutup TextField).
class OmniEmojiPickerSheet {
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _OmniEmojiPickerBody(),
    );
  }
}

class _OmniEmojiPickerBody extends StatefulWidget {
  const _OmniEmojiPickerBody();

  @override
  State<_OmniEmojiPickerBody> createState() => _OmniEmojiPickerBodyState();
}

class _OmniEmojiPickerBodyState extends State<_OmniEmojiPickerBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: omniEmojiCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.52;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OmniTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Text(
                  'Emoji',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OmniTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: OmniTheme.textSecondary),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: OmniTheme.primary,
            unselectedLabelColor: OmniTheme.textSecondary,
            indicatorColor: OmniTheme.primary,
            tabAlignment: TabAlignment.start,
            tabs: omniEmojiCategories
                .map((c) => Tab(text: '${c.icon} ${c.label}'))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: omniEmojiCategories.map((cat) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: cat.emojis.length,
                  itemBuilder: (context, i) {
                    final em = cat.emojis[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(context, em),
                        child: Center(
                          child: Text(em, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
