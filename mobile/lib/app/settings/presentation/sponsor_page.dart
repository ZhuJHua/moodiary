import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;
import 'package:url_launcher/url_launcher.dart';

class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: .externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('赞助')),
      body: ListView(
        padding: const .all(24),
        children: [
          Icon(LucideIcons.heart, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            '感谢您的考虑！',
            textAlign: .center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Moodiary 是开源软件，由开发者业余维护。'
            '如果您喜欢这款应用，可通过下面的链接支持作者继续维护。',
            textAlign: .center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                _open(context, 'https://github.com/sponsors/ZhuJHua'),
            icon: const Icon(LucideIcons.externalLink),
            label: const Text('GitHub Sponsors'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _open(context, 'https://afdian.com/a/ZhuJHua'),
            icon: const Icon(LucideIcons.externalLink),
            label: const Text('爱发电'),
          ),
        ],
      ),
    );
  }
}
