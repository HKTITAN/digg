import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../widgets/digg_logo.dart';
import 'story_screen.dart';

class ProfileScreen extends StatefulWidget {
  final DiggClient client;
  final String username;
  const ProfileScreen({super.key, required this.client, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<Story> _featured = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.client.getProfile(widget.username);
      List<Story> f = const [];
      if (p.onDigg) {
        try {
          f = await widget.client.getStoriesFeaturing(widget.username);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _profile = p;
        _featured = f;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: [
          if (_profile?.profileUrl != null)
            IconButton(
              tooltip: 'Open on digg.com',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(_profile!.profileUrl!)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DiggColors.green))
          : _profile == null
              ? _errorView()
              : _profile!.onDigg
                  ? _onDigg(_profile!)
                  : _notOnDigg(),
    );
  }

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: DiggColors.fgSoft, size: 40),
              const SizedBox(height: 12),
              const Text('Couldn’t look up that profile',
                  style: TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700)),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _notOnDigg() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DiggMark(size: 36),
              const SizedBox(height: 16),
              Text(
                '@${widget.username} isn’t tracked by Digg',
                style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Digg only ranks accounts in its AI-news index. Try a different handle from the Search tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _onDigg(Profile p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            const DiggWordmark(height: 20),
            const Spacer(),
            if (p.profileUrl != null)
              FilledButton.tonal(
                onPressed: () => launchUrl(Uri.parse(p.profileUrl!)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: DiggColors.fg,
                  side: const BorderSide(color: DiggColors.border),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('View on Digg'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (p.gravity != null || p.topFollowers != null || p.followers != null) ...[
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              if (p.gravity != null) _stat(p.gravity!, 'Gravity'),
              if (p.topFollowers != null) _stat(p.topFollowers!, 'Top followers'),
              if (p.followers != null) _stat(p.followers!, 'Followers'),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (p.category != null) ...[
          Wrap(
            spacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: DiggColors.greenSoft,
                  border: Border.all(color: DiggColors.greenRing),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  p.category!.label,
                  style: const TextStyle(color: DiggColors.green, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (p.classification != null) ...[
          const _SectionLabel('AI Classification'),
          const SizedBox(height: 6),
          Text(
            p.classification!,
            style: const TextStyle(color: DiggColors.fg, fontSize: 14, height: 1.5),
          ),
        ],
        if (p.vibe != null || p.topic != null) ...[
          const SizedBox(height: 20),
          const _SectionLabel('Vibe & Topics'),
          const SizedBox(height: 8),
          _chips(p.vibe),
          if (p.vibe != null && p.topic != null) const SizedBox(height: 8),
          _chips(p.topic),
        ],
        if (_featured.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionLabel('Featured in'),
          const SizedBox(height: 8),
          for (final s in _featured.take(5))
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoryScreen(client: widget.client, slug: s.slug),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [if (s.rank != null) '#${s.rank}', if (s.postCount != null) '${s.postCount} posts']
                          .join(' · '),
                      style: const TextStyle(color: DiggColors.green, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.displayTitle,
                      style: const TextStyle(color: DiggColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(label, style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _chips(Map<String, double>? m) {
    if (m == null) return const SizedBox.shrink();
    final entries = m.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries.take(8))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: DiggColors.border),
              borderRadius: BorderRadius.circular(9999),
              color: const Color(0x14000000),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.key.replaceAll('_', ' '),
                  style: const TextStyle(color: DiggColors.fg, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  '${e.value.toStringAsFixed(e.value >= 10 ? 0 : 1)}%',
                  style: const TextStyle(color: DiggColors.green, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: DiggColors.fg, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.7,
        ),
      );
}
