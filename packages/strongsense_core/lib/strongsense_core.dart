/// StrongSense AI domain core.
///
/// Pure Dart — no Flutter imports. Consumed by the Flutter app and exercised by
/// `dart test`. The JSON shapes mirror `docs/contract/contract.md` v1.
library;

export 'src/backup/backup_document.dart';
export 'src/backup/backup_merger.dart';
export 'src/backup/session_csv_exporter.dart';
export 'src/contract/coach_contract.dart';
export 'src/engines/autoregulation_engine.dart';
export 'src/engines/e1rm.dart';
export 'src/engines/pain_guidance.dart';
export 'src/engines/program_seed.dart';
export 'src/engines/progression_engine.dart';
export 'src/engines/readiness_engine.dart';
export 'src/engines/records_calculator.dart';
export 'src/engines/safety_bounds.dart';
export 'src/engines/session_classifier.dart';
export 'src/engines/session_summary_calculator.dart';
export 'src/engines/target_resolver.dart';
export 'src/engines/tips_library.dart';
export 'src/engines/training_math.dart';
export 'src/json/json_utils.dart';
export 'src/models/app_settings.dart';
export 'src/models/check_in.dart';
export 'src/models/coach_context.dart';
export 'src/models/coach_plan.dart';
export 'src/models/enums.dart';
export 'src/models/personal_record.dart';
export 'src/models/program.dart';
export 'src/models/readiness.dart';
export 'src/models/session.dart';
export 'src/models/session_plan.dart';
export 'src/models/session_summary.dart';
