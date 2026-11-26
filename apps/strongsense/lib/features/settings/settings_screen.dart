import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/widgets/ss_card.dart';
import '../../data/remote/coach_api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _weightController;
  late final TextEditingController _tokenController;
  Timer? _debounce;
  bool _testing = false;
  bool _tokenVisible = false;
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsControllerProvider);
    _nameController = TextEditingController(text: settings.userName);
    _urlController = TextEditingController(text: settings.coachBaseUrl);
    _tokenController = TextEditingController(text: settings.coachToken);
    _weightController = TextEditingController(
      text: settings.bodyWeightKg == null
          ? ''
          : settings.bodyWeightKg!.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _debounced(VoidCallback action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), action);
  }

  Future<void> _update(AppSettings next) =>
      ref.read(settingsControllerProvider.notifier).update(next);

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    setState(() => _testing = true);
    try {
      final health = await CoachApiClient(baseUrl: url).health();
      if (!mounted) {
        return;
      }
      final message = health.llmConfigured
          ? '${l10n.settingsConnectionOk} · ${health.primaryModel}'
          : l10n.settingsConnectionOk;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on CoachApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.settingsConnectionFail}: ${error.message}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _resetData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsReset),
        content: Text(l10n.settingsResetConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    const defaults = AppSettings();
    await ref.read(sessionRepositoryProvider).deleteAll();
    await ref.read(coachPlanRepositoryProvider).deleteAll();
    await ref.read(settingsRepositoryProvider).save(defaults);
    await ref.read(programRepositoryProvider).save(ProgramSeed.powerbuilding());
    await ref.read(settingsControllerProvider.notifier).update(defaults);
    await ref
        .read(programControllerProvider.notifier)
        .save(ProgramSeed.powerbuilding());
    ref.read(sessionControllerProvider.notifier).clear();
    ref.invalidate(historyProvider);
    ref.invalidate(latestCoachPlanProvider);
    if (mounted) {
      context.go('/onboarding');
    }
  }

  String _fileStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportJson() => _exportFile(
    fileName: 'strongsense-backup-${_fileStamp()}.json',
    mimeType: 'application/json',
    build: () => ref.read(backupServiceProvider).exportJson(),
  );

  Future<void> _exportCsv() => _exportFile(
    fileName: 'strongsense-sessions-${_fileStamp()}.csv',
    mimeType: 'text/csv; charset=utf-8',
    build: () => ref.read(backupServiceProvider).exportCsv(),
  );

  Future<void> _exportFile({
    required String fileName,
    required String mimeType,
    required Future<String> Function() build,
  }) async {
    if (_backupBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _backupBusy = true);
    try {
      final content = await build();
      final saved = await ref
          .read(backupFileServiceProvider)
          .exportText(fileName: fileName, content: content, mimeType: mimeType);
      if (saved) {
        _showMessage(l10n.settingsBackupExported);
      }
    } catch (error) {
      _showMessage('${l10n.settingsBackupExportFailed}: $error');
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  Future<void> _importBackup() async {
    if (_backupBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final String? content;
    try {
      content = await ref.read(backupFileServiceProvider).pickJsonText();
    } catch (error) {
      _showMessage('${l10n.settingsImportFailed}: $error');
      return;
    }
    if (content == null || !mounted) {
      return;
    }

    final mode = await showDialog<BackupImportMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsImportTitle),
        content: Text(l10n.settingsImportBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupImportMode.merge),
            child: Text(l10n.settingsImportMerge),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupImportMode.replace),
            child: Text(l10n.settingsImportReplace),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) {
      return;
    }

    setState(() => _backupBusy = true);
    try {
      final result = await ref
          .read(backupServiceProvider)
          .importJson(content, mode: mode);
      await ref
          .read(settingsControllerProvider.notifier)
          .update(result.settings);
      await ref.read(programControllerProvider.notifier).save(result.program);
      ref.read(sessionControllerProvider.notifier).clear();
      final inProgress = await ref
          .read(sessionRepositoryProvider)
          .loadInProgress();
      if (inProgress != null) {
        await ref.read(sessionControllerProvider.notifier).load(inProgress.id);
      }
      ref.invalidate(historyProvider);
      ref.invalidate(latestCoachPlanProvider);
      _showMessage(
        l10n.settingsImportDone(result.sessionCount, result.coachPlanCount),
      );
    } catch (error) {
      _showMessage('${l10n.settingsImportFailed}: $error');
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  String _programTemplateLabel(TrainingProgram program) {
    final l10n = AppLocalizations.of(context);
    final template = program.template;
    if (template == null) {
      return program.name;
    }
    final definition = ProgramTemplates.byId(template.templateId);
    final name = definition?.name ?? template.templateId;
    return '$name · ${l10n.settingsProgramWeek(template.week)}';
  }

  Future<void> _chooseProgramTemplate() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<ProgramTemplateDefinition>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final template in ProgramTemplates.all)
              ListTile(
                title: Text(template.name),
                subtitle: Text(l10n.programTemplateDescription(template.id)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(sheetContext).pop(template),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsProgramTemplateConfirmTitle),
        content: Text(l10n.settingsProgramTemplateConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsProgramTemplateConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final next = ref
        .read(programTemplateServiceProvider)
        .select(
          template: selected,
          current: ref.read(programControllerProvider),
          increments: ref.read(settingsControllerProvider).increments,
        );
    await ref.read(programControllerProvider.notifier).save(next);
    if (mounted) {
      _showMessage(l10n.settingsProgramTemplateApplied(selected.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final program = ref.watch(programControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.section,
        ),
        children: <Widget>[
          SsSectionHeader(
            title: l10n.onboardingName,
            icon: Icons.person_outline_rounded,
          ),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingName,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (value) => _debounced(
                    () => _update(settings.copyWith(userName: value.trim())),
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                Text(l10n.onboardingUnits, style: theme.textTheme.titleSmall),
                const SizedBox(height: SsSpacing.sm),
                SegmentedButton<Unit>(
                  segments: const <ButtonSegment<Unit>>[
                    ButtonSegment<Unit>(value: Unit.kg, label: Text('kg')),
                    ButtonSegment<Unit>(value: Unit.lb, label: Text('lb')),
                  ],
                  selected: <Unit>{settings.unit},
                  onSelectionChanged: (selection) =>
                      _update(settings.copyWith(unit: selection.first)),
                ),
                const SizedBox(height: SsSpacing.md),
                Text(l10n.settingsLanguage, style: theme.textTheme.titleSmall),
                const SizedBox(height: SsSpacing.sm),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'en', label: Text('English')),
                    ButtonSegment<String>(value: 'es', label: Text('Español')),
                  ],
                  selected: <String>{settings.language},
                  onSelectionChanged: (selection) =>
                      _update(settings.copyWith(language: selection.first)),
                ),
                const SizedBox(height: SsSpacing.md),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.onboardingBodyweight,
                    suffixText: settings.unit.wire,
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  ),
                  onChanged: (value) => _debounced(() {
                    final parsed = double.tryParse(
                      value.trim().replaceAll(',', '.'),
                    );
                    _update(
                      parsed == null
                          ? settings.copyWith(clearBodyWeight: true)
                          : settings.copyWith(bodyWeightKg: parsed),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsAppearance,
            icon: Icons.palette_outlined,
          ),
          SsCard(
            child: DropdownButtonFormField<String>(
              initialValue: settings.theme,
              decoration: InputDecoration(labelText: l10n.settingsAppearance),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'system',
                  child: Text(l10n.settingsSystemTheme),
                ),
                DropdownMenuItem<String>(
                  value: 'light',
                  child: Text(l10n.planSourceRules),
                ),
                DropdownMenuItem<String>(
                  value: 'dark',
                  child: Text(l10n.settingsDarkMode),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _update(settings.copyWith(theme: value));
                }
              },
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsCoach,
            icon: Icons.auto_awesome_rounded,
          ),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsCoachEnabled),
                    subtitle: Text(l10n.coachOfflineHint),
                    value: settings.coachEnabled,
                    onChanged: (value) =>
                        _update(settings.copyWith(coachEnabled: value)),
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCoachUrl,
                    hintText: l10n.settingsCoachUrlHint,
                    prefixIcon: const Icon(Icons.dns_outlined),
                  ),
                  onChanged: (value) => _debounced(
                    () =>
                        _update(settings.copyWith(coachBaseUrl: value.trim())),
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                TextField(
                  key: const ValueKey<String>('coach-token'),
                  controller: _tokenController,
                  obscureText: !_tokenVisible,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCoachToken,
                    hintText: l10n.settingsCoachTokenHint,
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _tokenVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _tokenVisible = !_tokenVisible),
                    ),
                  ),
                  onChanged: (value) => _debounced(
                    () => _update(settings.copyWith(coachToken: value.trim())),
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lan_outlined, size: 18),
                  label: Text(l10n.settingsTestConnection),
                ),
                const SizedBox(height: SsSpacing.sm),
                Text(
                  l10n.settingsCoachHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsIncrements,
            icon: Icons.straighten_rounded,
          ),
          SsCard(
            child: Column(
              children: <Widget>[
                _incrementRow(
                  settings,
                  label: 'Bench',
                  value: settings.increments.benchKg,
                  onChanged: (value) => _update(
                    settings.copyWith(
                      increments: Increments(
                        benchKg: value,
                        squatKg: settings.increments.squatKg,
                        deadliftKg: settings.increments.deadliftKg,
                        accessoryKg: settings.increments.accessoryKg,
                      ),
                    ),
                  ),
                ),
                _incrementRow(
                  settings,
                  label: 'Squat',
                  value: settings.increments.squatKg,
                  onChanged: (value) => _update(
                    settings.copyWith(
                      increments: Increments(
                        benchKg: settings.increments.benchKg,
                        squatKg: value,
                        deadliftKg: settings.increments.deadliftKg,
                        accessoryKg: settings.increments.accessoryKg,
                      ),
                    ),
                  ),
                ),
                _incrementRow(
                  settings,
                  label: 'Deadlift',
                  value: settings.increments.deadliftKg,
                  onChanged: (value) => _update(
                    settings.copyWith(
                      increments: Increments(
                        benchKg: settings.increments.benchKg,
                        squatKg: settings.increments.squatKg,
                        deadliftKg: value,
                        accessoryKg: settings.increments.accessoryKg,
                      ),
                    ),
                  ),
                ),
                _incrementRow(
                  settings,
                  label: 'Accessory',
                  value: settings.increments.accessoryKg,
                  onChanged: (value) => _update(
                    settings.copyWith(
                      increments: Increments(
                        benchKg: settings.increments.benchKg,
                        squatKg: settings.increments.squatKg,
                        deadliftKg: settings.increments.deadliftKg,
                        accessoryKg: value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsProgram,
            icon: Icons.list_alt_rounded,
          ),
          SsCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(
                      Icons.fitness_center_rounded,
                      color: SsColors.emerald600,
                    ),
                    title: Text(l10n.programTitle),
                    subtitle: Text(l10n.onboardingProgramBody),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/program'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.dashboard_customize_outlined,
                      color: SsColors.emerald600,
                    ),
                    title: Text(l10n.settingsProgramTemplate),
                    subtitle: Text(_programTemplateLabel(program)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseProgramTemplate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsData,
            icon: Icons.storage_outlined,
          ),
          if (_backupBusy) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: SsSpacing.sm),
            Text(
              l10n.settingsBackupWorking,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          SsCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(
                      Icons.file_upload_outlined,
                      color: SsColors.emerald600,
                    ),
                    title: Text(l10n.settingsExportBackup),
                    subtitle: Text(l10n.settingsExportBackupBody),
                    enabled: !_backupBusy,
                    onTap: _exportJson,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.table_view_outlined,
                      color: SsColors.emerald600,
                    ),
                    title: Text(l10n.settingsExportCsv),
                    subtitle: Text(l10n.settingsExportCsvBody),
                    enabled: !_backupBusy,
                    onTap: _exportCsv,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.file_download_outlined,
                      color: SsColors.emerald600,
                    ),
                    title: Text(l10n.settingsImportBackup),
                    subtitle: Text(l10n.settingsImportBackupBody),
                    enabled: !_backupBusy,
                    onTap: _importBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: SsColors.red500,
                    ),
                    title: Text(
                      l10n.settingsReset,
                      style: const TextStyle(color: SsColors.red500),
                    ),
                    enabled: !_backupBusy,
                    onTap: _resetData,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.settingsAbout,
            icon: Icons.info_outline_rounded,
          ),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      l10n.settingsVersion,
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '0.1.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SsSpacing.md),
                Text(
                  l10n.settingsDisclaimer,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  l10n.planDisclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incrementRow(
    AppSettings settings, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          DropdownButton<double>(
            value: value,
            underline: const SizedBox.shrink(),
            items: const <DropdownMenuItem<double>>[
              DropdownMenuItem<double>(value: 1.0, child: Text('1.0 kg')),
              DropdownMenuItem<double>(value: 2.5, child: Text('2.5 kg')),
              DropdownMenuItem<double>(value: 5.0, child: Text('5.0 kg')),
            ],
            onChanged: (next) {
              if (next != null) {
                onChanged(next);
              }
            },
          ),
        ],
      ),
    );
  }
}
