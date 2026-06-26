import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/catalog_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/library_screen.dart';
import 'services/jm_api.dart';
import 'widgets/app_logo.dart';

const _appLockEnabledKey = 'jm_visual_app_lock_enabled';
const _appLockPasswordKey = 'jm_visual_app_lock_password';
const _themeModeKey = 'jm_visual_theme_mode';

void main() {
  runApp(const JmVisualApp());
}

class JmVisualApp extends StatefulWidget {
  const JmVisualApp({super.key});

  @override
  State<JmVisualApp> createState() => _JmVisualAppState();
}

class _JmVisualAppState extends State<JmVisualApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModeKey);
    if (!mounted || saved == null) return;
    setState(() {
      _themeMode = switch (saved) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      },
    );
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JM Visual',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: _AppLockGate(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFFF06B4F) : const Color(0xFFFF6B9A),
      brightness: brightness,
      surface: dark ? const Color(0xFF0B151B) : const Color(0xFFFFFCFD),
    ).copyWith(
      primary: dark ? const Color(0xFFF06B4F) : const Color(0xFFFF5F93),
      secondary: dark ? const Color(0xFF56B6A8) : const Color(0xFF009EAA),
      tertiary: dark ? const Color(0xFFF0B44F) : const Color(0xFFF28A3D),
      primaryContainer:
          dark ? const Color(0xFF5A241E) : const Color(0xFFFFE1EC),
      secondaryContainer:
          dark ? const Color(0xFF123E3B) : const Color(0xFFD7F8F6),
      tertiaryContainer:
          dark ? const Color(0xFF543813) : const Color(0xFFFFF0B8),
      surface: dark ? const Color(0xFF0B151B) : const Color(0xFFFFFCFD),
      surfaceContainerHighest:
          dark ? const Color(0xFF14242C) : const Color(0xFFF1F5F7),
      outline: dark ? const Color(0xFF95A69F) : const Color(0xFF6F7C86),
      outlineVariant: dark ? const Color(0xFF2A3B42) : const Color(0xFFD8E1E7),
    );

    final baseTextTheme =
        dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textColor = dark ? const Color(0xFFE9F1EA) : const Color(0xFF25313A);
    final textTheme = GoogleFonts.notoSansScTextTheme(baseTextTheme)
        .copyWith(
          headlineMedium: GoogleFonts.bricolageGrotesque(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
          titleLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 20, fontWeight: FontWeight.w800),
          titleMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 17, fontWeight: FontWeight.w800),
          titleSmall: GoogleFonts.bricolageGrotesque(
              fontSize: 15, fontWeight: FontWeight.w700),
          bodyLarge: GoogleFonts.notoSansSc(fontSize: 14, height: 1.35),
          bodyMedium: GoogleFonts.notoSansSc(fontSize: 13, height: 1.35),
          bodySmall: GoogleFonts.notoSansSc(fontSize: 12, height: 1.35),
          labelLarge:
              GoogleFonts.notoSansSc(fontSize: 13, fontWeight: FontWeight.w700),
          labelMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
          labelSmall:
              GoogleFonts.notoSansSc(fontSize: 11, fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: textColor, displayColor: textColor);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
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
        fillColor: dark ? const Color(0xFF0F1E25) : const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            dark ? const Color(0xFF162A32) : const Color(0xFFFFF5D8),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor:
            dark ? const Color(0xFF0A1419) : const Color(0xFFFFFFFF),
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor:
            dark ? const Color(0xFF081216) : const Color(0xFFFFFFFF),
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelType: NavigationRailLabelType.none,
      ),
    );
  }
}

class _AppLockGate extends StatefulWidget {
  const _AppLockGate({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate> {
  bool _loading = true;
  bool _locked = false;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _loadLock();
  }

  Future<void> _loadLock() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_appLockEnabledKey) ?? false;
    final password = prefs.getString(_appLockPasswordKey) ?? '';
    if (!mounted) return;
    setState(() {
      _password = password;
      _locked = enabled && password.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_locked) {
      return _UnlockScreen(
        password: _password,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return HomeShell(
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }
}

class _UnlockScreen extends StatefulWidget {
  const _UnlockScreen({required this.password, required this.onUnlocked});

  final String password;
  final VoidCallback onUnlocked;

  @override
  State<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<_UnlockScreen> {
  final _controller = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == widget.password) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _error = '密码不正确';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(compact: false)),
                  const SizedBox(height: 28),
                  Text('输入开屏密码',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: '密码',
                      errorText: _error.isEmpty ? null : _error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('解锁'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _apiBaseKey = 'jm_visual_api_base';

  JmApi _api = JmApi();
  int _index = 0;
  int _libraryRefreshTick = 0;

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

  void _selectIndex(int value) {
    if (value == _index) return;
    setState(() {
      if (value == 1) _libraryRefreshTick++;
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CatalogScreen(key: ValueKey('catalog-${_api.baseUrl}'), api: _api),
      LibraryScreen(
        key: ValueKey('library-${_api.baseUrl}'),
        api: _api,
        refreshTick: _libraryRefreshTick,
      ),
      DownloadsScreen(key: ValueKey('downloads-${_api.baseUrl}'), api: _api),
      _SettingsScreen(
        key: ValueKey('settings-${_api.baseUrl}'),
        api: _api,
        themeMode: widget.themeMode,
        onApiBaseChanged: _setApiBase,
        onThemeModeChanged: widget.onThemeModeChanged,
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
                  onDestinationSelected: _selectIndex,
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
                      icon: Icon(Icons.local_library_outlined),
                      selectedIcon: Icon(Icons.local_library),
                      label: Text('书架'),
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
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: _index, children: screens),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectIndex,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: '列表'),
              NavigationDestination(
                  icon: Icon(Icons.local_library_outlined),
                  selectedIcon: Icon(Icons.local_library),
                  label: '书架'),
              NavigationDestination(
                  icon: Icon(Icons.downloading_outlined),
                  selectedIcon: Icon(Icons.download_done_outlined),
                  label: '下载'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置'),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({
    super.key,
    required this.api,
    required this.themeMode,
    required this.onApiBaseChanged,
    required this.onThemeModeChanged,
  });

  final JmApi api;
  final ThemeMode themeMode;
  final Future<void> Function(String value) onApiBaseChanged;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late final TextEditingController _apiBaseController;
  late final TextEditingController _lockPasswordController;
  late final TextEditingController _barkController;
  late Future<Map<String, dynamic>> _future;
  late Future<VisualSettings> _settingsFuture;
  bool _saving = false;
  bool _lockEnabled = false;
  bool _hasLockPassword = false;
  bool _lockSaving = false;
  bool _settingsSaving = false;
  int _watchIntervalMinutes = 60;

  @override
  void initState() {
    super.initState();
    _apiBaseController = TextEditingController(text: widget.api.baseUrl);
    _lockPasswordController = TextEditingController();
    _barkController = TextEditingController();
    _future = widget.api.health();
    _settingsFuture = _loadVisualSettings();
    _loadAppLock();
  }

  @override
  void didUpdateWidget(covariant _SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.baseUrl != widget.api.baseUrl) {
      _apiBaseController.text = widget.api.baseUrl;
      _future = widget.api.health();
      _settingsFuture = _loadVisualSettings();
    }
  }

  @override
  void dispose() {
    _apiBaseController.dispose();
    _lockPasswordController.dispose();
    _barkController.dispose();
    super.dispose();
  }

  Future<VisualSettings> _loadVisualSettings() async {
    final settings = await widget.api.settings();
    _barkController.text = settings.barkUrls.join('\n');
    _watchIntervalMinutes = settings.watchIntervalMinutes;
    return settings;
  }

  Future<void> _saveVisualSettings() async {
    setState(() => _settingsSaving = true);
    try {
      final urls = _barkController.text
          .split(RegExp(r'[\n,]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      final settings = await widget.api.saveSettings(VisualSettings(
        barkUrls: urls,
        watchIntervalMinutes: _watchIntervalMinutes,
      ));
      if (!mounted) return;
      setState(() {
        _barkController.text = settings.barkUrls.join('\n');
        _watchIntervalMinutes = settings.watchIntervalMinutes;
        _settingsFuture = Future.value(settings);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('通知设置已保存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('通知设置保存失败：$error')));
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  Future<void> _saveApiBase() async {
    setState(() => _saving = true);
    try {
      await widget.onApiBaseChanged(_apiBaseController.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('API 地址已保存')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
      _hasLockPassword =
          (prefs.getString(_appLockPasswordKey) ?? '').isNotEmpty;
    });
  }

  Future<void> _saveAppLock({bool? enabled}) async {
    final nextEnabled = enabled ?? _lockEnabled;
    final password = _lockPasswordController.text;
    if (nextEnabled && password.isEmpty && !_hasLockPassword) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先设置开屏密码')));
      return;
    }

    setState(() {
      _lockSaving = true;
      _lockEnabled = nextEnabled;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appLockEnabledKey, nextEnabled);
      if (password.isNotEmpty) {
        await prefs.setString(_appLockPasswordKey, password);
      }
      if (!mounted) return;
      setState(() {
        _hasLockPassword = password.isNotEmpty || _hasLockPassword;
        _lockPasswordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextEnabled ? '开屏密码已开启' : '开屏密码已关闭')));
    } finally {
      if (mounted) setState(() => _lockSaving = false);
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
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
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
                _AppLockPanel(
                  enabled: _lockEnabled,
                  saving: _lockSaving,
                  hasPassword: _hasLockPassword,
                  controller: _lockPasswordController,
                  onEnabledChanged: (value) => _saveAppLock(enabled: value),
                  onSave: () => _saveAppLock(),
                ),
                const SizedBox(height: 14),
                _ThemePanel(
                  value: widget.themeMode,
                  onChanged: widget.onThemeModeChanged,
                ),
                const SizedBox(height: 14),
                FutureBuilder<VisualSettings>(
                  future: _settingsFuture,
                  builder: (context, snapshot) {
                    final loading =
                        snapshot.connectionState != ConnectionState.done;
                    return _BarkPanel(
                      controller: _barkController,
                      saving: _settingsSaving,
                      loading: loading,
                      intervalMinutes: _watchIntervalMinutes,
                      onIntervalChanged: (value) =>
                          setState(() => _watchIntervalMinutes = value),
                      onSave: _saveVisualSettings,
                    );
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
                          onPressed: () =>
                              setState(() => _future = widget.api.health()),
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
                        onPressed: () =>
                            setState(() => _future = widget.api.health()),
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
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined,
                  size: 19, color: theme.colorScheme.secondary),
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
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

class _AppLockPanel extends StatelessWidget {
  const _AppLockPanel({
    required this.enabled,
    required this.saving,
    required this.hasPassword,
    required this.controller,
    required this.onEnabledChanged,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final bool hasPassword;
  final TextEditingController controller;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: saving ? null : onEnabledChanged,
              title: Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 19, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text('开屏密码', style: theme.textTheme.titleSmall),
                ],
              ),
              subtitle: Text(
                enabled ? '下次启动应用时需要输入密码。' : '默认关闭，开启后保护本地阅读入口。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.password_outlined),
              hintText: hasPassword ? '输入新密码可修改' : '设置开屏密码',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(saving ? '保存中' : '保存密码设置'),
          ),
        ],
      ),
    );
  }
}

class _ThemePanel extends StatelessWidget {
  const _ThemePanel({required this.value, required this.onChanged});

  final ThemeMode value;
  final Future<void> Function(ThemeMode mode) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined,
                  size: 19, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text('主题', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('暗色'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('亮色'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('系统'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selected) => onChanged(selected.first),
          ),
        ],
      ),
    );
  }
}

class _BarkPanel extends StatelessWidget {
  const _BarkPanel({
    required this.controller,
    required this.saving,
    required this.loading,
    required this.intervalMinutes,
    required this.onIntervalChanged,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final bool loading;
  final int intervalMinutes;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback onSave;

  static const _intervals = [15, 30, 60, 180, 360, 720, 1440];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intervalValue =
        _intervals.contains(intervalMinutes) ? intervalMinutes : 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 19, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text('更新通知', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link_outlined),
              hintText: 'Bark 地址，每行一个',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: intervalValue,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 分钟')),
                DropdownMenuItem(value: 30, child: Text('30 分钟')),
                DropdownMenuItem(value: 60, child: Text('1 小时')),
                DropdownMenuItem(value: 180, child: Text('3 小时')),
                DropdownMenuItem(value: 360, child: Text('6 小时')),
                DropdownMenuItem(value: 720, child: Text('12 小时')),
                DropdownMenuItem(value: 1440, child: Text('24 小时')),
              ],
              onChanged: saving || loading
                  ? null
                  : (value) => onIntervalChanged(value ?? 60),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving || loading ? null : onSave,
            icon: saving || loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(saving ? '保存中' : '保存通知设置'),
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
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
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
