import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/catalog_screen.dart';
import 'screens/downloads_screen.dart';
import 'services/jm_api.dart';
import 'widgets/app_logo.dart';

void main() {
  runApp(const JmVisualApp());
}

class JmVisualApp extends StatelessWidget {
  const JmVisualApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFF06B4F);
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0B151B),
    );
    final scheme = base.copyWith(
      primary: const Color(0xFFF06B4F),
      secondary: const Color(0xFF56B6A8),
      tertiary: const Color(0xFFF0B44F),
      surface: const Color(0xFF0B151B),
      surfaceContainerHighest: const Color(0xFF14242C),
      outline: const Color(0xFF95A69F),
      outlineVariant: const Color(0xFF2A3B42),
    );

    final textTheme = GoogleFonts.notoSansScTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      headlineMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.bricolageGrotesque(fontSize: 17, fontWeight: FontWeight.w800),
      titleSmall: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.notoSansSc(fontSize: 14, height: 1.35),
      bodyMedium: GoogleFonts.notoSansSc(fontSize: 13, height: 1.35),
      bodySmall: GoogleFonts.notoSansSc(fontSize: 12, height: 1.35),
      labelLarge: GoogleFonts.notoSansSc(fontSize: 13, fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.notoSansSc(fontSize: 11, fontWeight: FontWeight.w700),
    ).apply(bodyColor: const Color(0xFFE9F1EA), displayColor: const Color(0xFFE9F1EA));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JM Visual',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: scheme.surface,
        textTheme: textTheme,
        visualDensity: VisualDensity.compact,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface.withValues(alpha: .94),
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: textTheme.titleMedium,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F1E25),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF162A32),
          side: BorderSide(color: scheme.outlineVariant),
          labelStyle: TextStyle(color: scheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          backgroundColor: const Color(0xFF0A1419),
          indicatorColor: scheme.primary.withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xFF081216),
          indicatorColor: scheme.primary.withValues(alpha: .18),
          labelType: NavigationRailLabelType.none,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _apiBaseKey = 'jm_visual_api_base';

  JmApi _api = JmApi();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadApiBase();
  }

  Future<void> _loadApiBase() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiBaseKey);
    if (!mounted || saved == null || saved.trim().isEmpty) return;
    setState(() => _api = JmApi(baseUrl: saved));
  }

  Future<void> _setApiBase(String value) async {
    final cleaned = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (cleaned.isEmpty) {
      await prefs.remove(_apiBaseKey);
    } else {
      await prefs.setString(_apiBaseKey, cleaned);
    }
    if (!mounted) return;
    setState(() => _api = JmApi(baseUrl: cleaned.isEmpty ? null : cleaned));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CatalogScreen(key: ValueKey('catalog-${_api.baseUrl}'), api: _api),
      DownloadsScreen(key: ValueKey('downloads-${_api.baseUrl}'), api: _api),
      _SettingsScreen(
        key: ValueKey('settings-${_api.baseUrl}'),
        api: _api,
        onApiBaseChanged: _setApiBase,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  minWidth: 76,
                  extended: constraints.maxWidth >= 1080,
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  leading: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 20, 12, 24),
                    child: AppLogo(compact: true),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view),
                      label: Text('列表'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.downloading_outlined),
                      selectedIcon: Icon(Icons.download_done_outlined),
                      label: Text('下载'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[_index]),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const AppLogo(compact: true)),
          body: screens[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '列表'),
              NavigationDestination(icon: Icon(Icons.downloading_outlined), selectedIcon: Icon(Icons.download_done_outlined), label: '下载'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({super.key, required this.api, required this.onApiBaseChanged});

  final JmApi api;
  final Future<void> Function(String value) onApiBaseChanged;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late final TextEditingController _apiBaseController;
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiBaseController = TextEditingController(text: widget.api.baseUrl);
    _future = widget.api.health();
  }

  @override
  void didUpdateWidget(covariant _SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.baseUrl != widget.api.baseUrl) {
      _apiBaseController.text = widget.api.baseUrl;
      _future = widget.api.health();
    }
  }

  @override
  void dispose() {
    _apiBaseController.dispose();
    super.dispose();
  }

  Future<void> _saveApiBase() async {
    setState(() => _saving = true);
    try {
      await widget.onApiBaseChanged(_apiBaseController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API 地址已保存')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '客户端通过本地 API 服务连接 jmcomic。',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 18),
                _ApiBasePanel(
                  controller: _apiBaseController,
                  saving: _saving,
                  defaultBaseUrl: JmApi.defaultBaseUrl(),
                  onSave: _saveApiBase,
                  onReset: () {
                    _apiBaseController.clear();
                    _saveApiBase();
                  },
                ),
                const SizedBox(height: 14),
                FutureBuilder<Map<String, dynamic>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _InfoPanel(
                        icon: Icons.cloud_off_outlined,
                        title: '后端未连接',
                        lines: [
                          snapshot.error.toString(),
                          '当前 API：${widget.api.baseUrl}',
                        ],
                        action: FilledButton.icon(
                          onPressed: () => setState(() => _future = widget.api.health()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      );
                    }
                    final info = snapshot.data!;
                    return _InfoPanel(
                      icon: Icons.check_circle_outline,
                      title: '后端已连接',
                      lines: [
                        'API：${widget.api.baseUrl}',
                        'jmcomic：${info['jmcomicVersion']}',
                        '下载目录：${info['downloadDir']}',
                        '缓存目录：${info['cacheDir']}',
                      ],
                      action: FilledButton.icon(
                        onPressed: () => setState(() => _future = widget.api.health()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('刷新'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ApiBasePanel extends StatelessWidget {
  const _ApiBasePanel({
    required this.controller,
    required this.saving,
    required this.defaultBaseUrl,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController controller;
  final bool saving;
  final String defaultBaseUrl;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 19, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text('API 地址', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            decoration: InputDecoration(
              hintText: 'https://api.example.com',
              helperText: '留空恢复默认：$defaultBaseUrl',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? '保存中' : '保存'),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : onReset,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('恢复默认'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.action,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(line),
            ),
          const SizedBox(height: 8),
          action,
        ],
      ),
    );
  }
}
