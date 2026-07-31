import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/glass_card.dart';

/// Everything about the person who made the app, in one place.
///
/// Kept as plain constants rather than a config file or a remote fetch: it
/// changes roughly never, and an app that promises to make no network calls
/// should not make one to find out who wrote it. Edit the values here and the
/// screen updates.
abstract final class DeveloperInfo {
  static const name = 'Arsalan Kaleem';
  static const role = 'Mobile developer';
  static const location = 'Karachi, Pakistan';

  static const bio =
      'I build things that respect the people using them. Nuntius came out of '
      'wanting to see what a decade of messages actually looks like, without '
      'handing that history to somebody else to read first.';

  static const email = 'you@example.com';

  /// Only entries with a non-empty url are shown, so deleting a line is enough
  /// to remove a link.
  static const links = <DeveloperLink>[
    DeveloperLink(
      label: 'GitHub',
      handle: '@yourhandle',
      url: 'https://github.com/yourhandle',
      icon: Icons.code_rounded,
    ),
    DeveloperLink(
      label: 'LinkedIn',
      handle: 'Your Name',
      url: 'https://linkedin.com/in/yourhandle',
      icon: Icons.work_outline_rounded,
    ),
    DeveloperLink(
      label: 'X',
      handle: '@yourhandle',
      url: 'https://x.com/yourhandle',
      icon: Icons.alternate_email_rounded,
    ),
    DeveloperLink(
      label: 'Instagram',
      handle: '@yourhandle',
      url: 'https://instagram.com/yourhandle',
      icon: Icons.camera_alt_outlined,
    ),
    DeveloperLink(
      label: 'Website',
      handle: 'yoursite.com',
      url: 'https://yoursite.com',
      icon: Icons.language_rounded,
    ),
  ];

  static String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class DeveloperLink {
  const DeveloperLink({
    required this.label,
    required this.handle,
    required this.url,
    required this.icon,
  });

  final String label;
  final String handle;
  final String url;
  final IconData icon;
}

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  /// Opening a link hands off to the browser, which is the one moment this app
  /// touches the network — and it does so by handing a URL to the OS rather
  /// than fetching anything itself. If no browser can take it, the address is
  /// copied instead, so the tap is never a dead end.
  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;

    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (opened) return;

    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      SnackBar(
        content: Text('Copied $url'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links =
        DeveloperInfo.links.where((l) => l.url.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppGradients.byIndex(0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DeveloperInfo.initials,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DeveloperInfo.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DeveloperInfo.role,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.accent),
                          ),
                          Text(
                            DeveloperInfo.location,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(DeveloperInfo.bio, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (links.isNotEmpty) ...[
            const SectionHeader('Elsewhere'),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final link in links)
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(link.icon,
                            size: 18, color: AppColors.accent),
                      ),
                      title: Text(link.label,
                          style: theme.textTheme.titleMedium),
                      subtitle: Text(
                        link.handle,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.north_east_rounded, size: 16),
                      onTap: () => _open(context, link.url),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const SectionHeader('Get in touch'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Email'),
                const SizedBox(height: 6),
                Text(DeveloperInfo.email, style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(
                          context,
                          'mailto:${DeveloperInfo.email}'
                          '?subject=${Uri.encodeComponent(AppInfo.name)}',
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: DeveloperInfo.email),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email copied'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader('About this app'),
          SurfaceCard(
            child: Column(
              children: [
                _Fact(label: 'App', value: AppInfo.name),
                _Fact(label: 'Version', value: AppInfo.version),
                _Fact(label: 'Built with', value: 'Flutter · Dart'),
                _Fact(
                  label: 'Processing',
                  value: 'On device',
                  detail: 'No server, no account, no analytics',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.detail,
    this.last = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (detail != null)
                  Text(detail!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
