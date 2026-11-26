import 'package:strongsense_core/strongsense_core.dart';

/// Builds a template program and advances it after a completed session.
class ProgramTemplateService {
  const ProgramTemplateService();

  TrainingProgram select({
    required ProgramTemplateDefinition template,
    required TrainingProgram current,
    required Increments increments,
  }) {
    final state = template.initialState(current, increments);
    return template.build(state, increments);
  }

  /// Returns the next program, or null when the current program is custom.
  TrainingProgram? advanceAfterSession({
    required Session session,
    required TrainingProgram program,
    required int completedSessions,
    required Increments increments,
  }) {
    final state = program.template;
    if (state == null) {
      return null;
    }
    final template = ProgramTemplates.byId(state.templateId);
    if (template == null) {
      return null;
    }
    final next = template.advance(
      state,
      session,
      completedSessions,
      increments,
    );
    return template.build(next, increments);
  }
}
