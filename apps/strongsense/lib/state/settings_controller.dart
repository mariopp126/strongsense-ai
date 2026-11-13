import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../data/repositories/settings_repository.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController({
    required SettingsRepository repository,
    required AppSettings initial,
  }) : _repository = repository,
       super(initial);

  final SettingsRepository _repository;

  Future<void> update(AppSettings next) async {
    state = next;
    await _repository.save(next);
  }

  Future<void> completeOnboarding({
    required String name,
    required Unit unit,
    double? bodyWeightKg,
  }) {
    return update(
      state.copyWith(
        userName: name.trim(),
        unit: unit,
        bodyWeightKg: bodyWeightKg,
        onboardingComplete: true,
      ),
    );
  }
}
