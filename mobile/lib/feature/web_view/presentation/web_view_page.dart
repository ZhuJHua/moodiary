import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 暂用 `url_launcher` 跳系统浏览器；引入 `webview_flutter` 后再切内置浏览模式。
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, this.title = ''});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_attempted) return;
    _attempted = true;
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? '浏览' : widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new, size: 48),
              const SizedBox(height: 12),
              Text(
                '已尝试在外部浏览器打开：',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                widget.url,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.refresh),
                label: const Text('再次打开'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
