import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../data/repositories/program_repository.dart';

class ProgramController extends StateNotifier<TrainingProgram> {
  ProgramController({
    required ProgramRepository repository,
    required TrainingProgram initial,
  }) : _repository = repository,
       super(initial);

  final ProgramRepository _repository;

  Future<void> save(TrainingProgram program) async {
    state = program;
    await _repository.save(program);
  }
}
