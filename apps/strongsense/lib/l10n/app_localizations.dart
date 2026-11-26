import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Lightweight English/Spanish localization (no codegen, synchronous load).
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  static const LocalizationsDelegate<dynamic> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  bool get _es => locale.languageCode == 'es';

  String get appName => 'StrongSense AI';

  // Navigation
  String get navHome => _es ? 'Inicio' : 'Home';
  String get navCoach => _es ? 'Coach' : 'Coach';
  String get navHistory => _es ? 'Historial' : 'History';
  String get navSettings => _es ? 'Ajustes' : 'Settings';

  // Common
  String get cancel => _es ? 'Cancelar' : 'Cancel';
  String get save => _es ? 'Guardar' : 'Save';
  String get delete => _es ? 'Eliminar' : 'Delete';
  String get close => _es ? 'Cerrar' : 'Close';
  String get continueLabel => _es ? 'Continuar' : 'Continue';
  String get back => _es ? 'Atrás' : 'Back';
  String get done => _es ? 'Listo' : 'Done';
  String get retry => _es ? 'Reintentar' : 'Retry';
  String get edit => _es ? 'Editar' : 'Edit';
  String get reset => _es ? 'Reiniciar' : 'Reset';
  String get loading => _es ? 'Cargando…' : 'Loading…';
  String get skip => _es ? 'Omitir' : 'Skip';
  String get kg => 'kg';
  String get lb => 'lb';
  String get min => _es ? 'min' : 'min';

  // Onboarding
  String get onboardingTitle => _es
      ? 'Entrena con cabeza,\nno solo con fuerza'
      : 'Train smart,\nnot just hard';
  String get onboardingBody => _es
      ? 'StrongSense ajusta tu press de banca, sentadilla y peso muerto según cómo te sientes y cómo fue tu última sesión.'
      : 'StrongSense adjusts your bench, squat and deadlift based on how you feel and how your last session went.';
  String get onboardingName =>
      _es ? '¿Cómo te llamas?' : 'What should we call you?';
  String get onboardingNameHint => _es ? 'Tu nombre' : 'Your name';
  String get onboardingUnits => _es ? 'Unidades' : 'Units';
  String get onboardingBodyweight =>
      _es ? 'Peso corporal (opcional)' : 'Bodyweight (optional)';
  String get onboardingBodyweightHint => _es ? 'ej. 82.5' : 'e.g. 82.5';
  String get onboardingStart => _es ? 'Empezar' : 'Get started';
  String get onboardingProgramTitle => _es ? 'Tu programa' : 'Your program';
  String get onboardingProgramBody => _es
      ? 'Powerbuilding de 3 días: sentadilla, banca y peso muerto con accesorios.'
      : '3-day powerbuilding: squat, bench and deadlift with accessories.';

  // Home
  String greeting(String name) => name.isEmpty
      ? (_es ? 'Hola' : 'Hey')
      : (_es ? 'Hola, $name' : 'Hey, $name');
  String get homeSubtitle => _es
      ? 'Tu siguiente sesión está lista cuando tú lo estés.'
      : 'Your next session is ready when you are.';
  String get homeToday => _es ? 'Sesión de hoy' : "Today's session";
  String get homeStartCheckIn => _es ? 'Hacer check-in' : 'Start check-in';
  String get homeResume => _es ? 'Retomar sesión' : 'Resume session';
  String get homeResumeBody => _es
      ? 'Tienes una sesión sin terminar.'
      : 'You have a workout in progress.';
  String get homeWeeklyVolume => _es ? 'Volumen semanal' : 'Weekly volume';
  String get homeStreak => _es ? 'Racha' : 'Streak';
  String streak(int days) => _es
      ? '$days ${days == 1 ? 'día' : 'días'}'
      : '$days ${days == 1 ? 'day' : 'days'}';
  String get homeRecent => _es ? 'Sesiones recientes' : 'Recent sessions';
  String get homeNoSessions => _es
      ? 'Aún no hay sesiones. Haz tu primer check-in.'
      : 'No sessions yet. Start with a check-in.';
  String get homePRs => _es ? 'Récords personales' : 'Personal records';
  String get homeNoPRs => _es
      ? 'Completa una sesión para estimar tus récords.'
      : 'Complete a session to estimate your records.';
  String get homeViewAll => _es ? 'Ver todo' : 'View all';

  // Check-in
  String get checkInTitle => _es ? 'Check-in de hoy' : "Today's check-in";
  String get checkInSubtitle => _es
      ? 'Un minuto para ajustar la sesión a cómo te sientes.'
      : 'One minute to tune the session to how you feel.';
  String get checkInSleepQuality => _es ? 'Calidad del sueño' : 'Sleep quality';
  String get checkInSleepHours => _es ? 'Horas de sueño' : 'Hours slept';
  String get checkInEnergy => _es ? 'Energía' : 'Energy';
  String get checkInMotivation => _es ? 'Motivación' : 'Motivation';
  String get checkInSoreness =>
      _es ? 'Agujetas / fatiga' : 'Soreness / fatigue';
  String get checkInStress => _es ? 'Estrés' : 'Stress';
  String get checkInPain => _es ? '¿Alguna molestia?' : 'Any pain?';
  String get checkInPainNone => _es ? 'Ninguna' : 'None';
  String get checkInPainSeverity =>
      _es ? 'Intensidad del dolor' : 'Pain severity';
  String get checkInTime => _es ? 'Tiempo disponible' : 'Time available';
  String get checkInNotes => _es ? 'Notas (opcional)' : 'Notes (optional)';
  String get checkInNotesHint => _es
      ? 'ej. el hombro derecho se siente raro'
      : 'e.g. right shoulder feels off';
  String get checkInGetPlan => _es ? 'Ver mi plan' : 'See my plan';
  String get checkInGenerating =>
      _es ? 'Preparando tu plan…' : 'Building your plan…';
  String painAreaLabel(String wire) {
    const en = <String, String>{
      'lower_back': 'Lower back',
      'knee': 'Knee',
      'shoulder': 'Shoulder',
      'elbow': 'Elbow',
      'wrist': 'Wrist',
      'hip': 'Hip',
      'other': 'Other',
    };
    const es = <String, String>{
      'lower_back': 'Espalda baja',
      'knee': 'Rodilla',
      'shoulder': 'Hombro',
      'elbow': 'Codo',
      'wrist': 'Muñeca',
      'hip': 'Cadera',
      'other': 'Otra',
    };
    return (_es ? es : en)[wire] ?? wire;
  }

  // Readiness
  String get readinessTitle => _es ? 'Tu disposición' : 'Your readiness';
  String score(int value) => _es ? '$value / 100' : '$value / 100';
  String get readinessWhy => _es ? '¿Por qué este plan?' : 'Why this plan?';
  String get readinessComponents => _es ? 'Componentes' : 'Components';
  String bandLabel(String wire) {
    const en = <String, String>{
      'green': 'Green',
      'amber': 'Amber',
      'orange': 'Orange',
      'red': 'Red',
    };
    const es = <String, String>{
      'green': 'Verde',
      'amber': 'Ámbar',
      'orange': 'Naranja',
      'red': 'Rojo',
    };
    return (_es ? es : en)[wire] ?? wire;
  }

  String bandAdvice(String wire) {
    const en = <String, String>{
      'green': 'Push the plan',
      'amber': 'Maintain and execute',
      'orange': 'Reduce and stay technical',
      'red': 'Recover or technique only',
    };
    const es = <String, String>{
      'green': 'Empuja el plan',
      'amber': 'Mantén y ejecuta',
      'orange': 'Reduce y cuida la técnica',
      'red': 'Recupera o solo técnica',
    };
    return (_es ? es : en)[wire] ?? wire;
  }

  String componentLabel(String key) {
    const en = <String, String>{
      'sleep': 'Sleep',
      'energy': 'Energy',
      'stress': 'Stress tolerance',
      'soreness': 'Freshness',
      'motivation': 'Motivation',
    };
    const es = <String, String>{
      'sleep': 'Sueño',
      'energy': 'Energía',
      'stress': 'Tolerancia al estrés',
      'soreness': 'Frescura',
      'motivation': 'Motivación',
    };
    return (_es ? es : en)[key] ?? key;
  }

  // Plan preview / coach
  String get planTitle => _es ? 'Tu plan de hoy' : "Today's plan";
  String get planAdjustments => _es ? 'Ajustes' : 'Adjustments';
  String get planTips => _es ? 'Consejos' : 'Tips';
  String get planFlags => _es ? 'Atención' : 'Heads up';
  String get planStart => _es ? 'Empezar entrenamiento' : 'Start workout';
  String get planRegenerate => _es ? 'Regenerar' : 'Regenerate';
  String get planAiThinking =>
      _es ? 'El coach IA está pensando…' : 'AI coach is thinking…';
  String get planAiUnavailable => _es
      ? 'IA no disponible: usando el coach offline.'
      : 'AI unavailable: using the offline coach.';
  String get planSourceRules => _es ? 'Coach offline' : 'Offline coach';
  String get planSourceAi => _es ? 'Coach IA' : 'AI coach';
  String get planSourceFallback =>
      _es ? 'Coach offline (respaldo)' : 'Offline coach (fallback)';
  String get planDeload => _es ? 'Semana de descarga' : 'Deload week';
  String get planDisclaimer => _es
      ? 'StrongSense AI ofrece orientación general de entrenamiento, no consejo médico. Detente y busca atención profesional si sientes dolor agudo, adormecimiento o una articulación que cede.'
      : 'StrongSense AI provides general training guidance, not medical advice. Stop and seek professional care if you feel sharp pain, numbness or a joint gives way.';
  String get coachTitle => _es ? 'Coach' : 'Coach';
  String get coachEmpty =>
      _es ? 'Tu coach está esperando' : 'Your coach is waiting';
  String get coachEmptyBody => _es
      ? 'Haz un check-in para recibir el plan de hoy, los ajustes y los consejos.'
      : 'Do a check-in to get today’s plan, adjustments and tips.';
  String get coachGoCheckIn => _es ? 'Hacer check-in' : 'Do a check-in';
  String get coachLatestPlan => _es ? 'Último plan' : 'Latest plan';

  // Workout
  String get workoutTitle => _es ? 'Entrenamiento' : 'Workout';
  String setsProgress(int done, int total) =>
      _es ? '$done / $total series' : '$done / $total sets';
  String setNumber(int value) => _es ? 'SERIE $value' : 'SET $value';
  String get workoutReps => _es ? 'Reps' : 'Reps';
  String get workoutWeight => _es ? 'Peso' : 'Weight';
  String get workoutRpe => _es ? 'RPE' : 'RPE';
  String get workoutTarget => _es ? 'Objetivo' : 'Target';
  String get workoutRest => _es ? 'Descanso' : 'Rest';
  String get workoutFinish => _es ? 'Terminar sesión' : 'Finish session';
  String get workoutFinishConfirm =>
      _es ? '¿Terminar el entrenamiento?' : 'Finish this workout?';
  String get workoutFinishBody => _es
      ? 'Se guardarán las series completadas y verás el resumen.'
      : 'Completed sets will be saved and you will see the summary.';
  String get workoutSessionRpe => _es ? 'RPE de la sesión' : 'Session RPE';
  String get workoutNotes => _es ? 'Notas de la sesión' : 'Session notes';
  String get workoutNotesHint =>
      _es ? '¿Cómo te sentiste?' : 'How did it feel?';
  String get workoutRestDone => _es ? 'Descanso terminado' : 'Rest done';
  String get workoutEditSet => _es ? 'Editar serie' : 'Edit set';
  String get workoutComplete => _es ? 'Completar' : 'Complete';
  String get workoutSkip => _es ? 'Omitir' : 'Skip';

  // Summary
  String get summaryTitle => _es ? 'Sesión completada' : 'Session complete';
  String get summaryLifts => _es ? 'Series por ejercicio' : 'Sets by lift';
  String get summarySubtitle => _es
      ? 'Buen trabajo. Esto es lo que moviste hoy.'
      : 'Good work. Here is what you moved today.';
  String get summaryVolume => _es ? 'Volumen total' : 'Total volume';
  String get summarySets => _es ? 'Series' : 'Sets';
  String get summaryMissed => _es ? 'Series falladas' : 'Missed sets';
  String get summaryDuration => _es ? 'Duración' : 'Duration';
  String get summarySessionRpe => _es ? 'RPE de sesión' : 'Session RPE';
  String get summaryNotes => _es ? 'Notas' : 'Notes';
  String get summarySave => _es ? 'Guardar y cerrar' : 'Save and close';
  String get summaryNextTime => _es ? 'Próxima sesión' : 'Next session';
  String get summaryPR => _es ? '¡Nuevo récord!' : 'New PR!';
  String get summaryViewHistory => _es ? 'Ver historial' : 'View history';

  // History
  String get historyTitle => _es ? 'Historial' : 'History';
  String get historySessionsTab => _es ? 'Sesiones' : 'Sessions';
  String get historyProgressTab => _es ? 'Progreso' : 'Progress';
  String get historyEmpty =>
      _es ? 'Todavía no hay historial' : 'No history yet';
  String get historyEmptyBody => _es
      ? 'Cuando completes una sesión aparecerá aquí con tu volumen y tus récords.'
      : 'Once you complete a session it will appear here with volume and records.';
  String get historyVolume => _es ? 'Volumen' : 'Volume';
  String get historyE1rm => _es ? '1RM estimado' : 'Estimated 1RM';
  String get historySelectLift => _es ? 'Elige un ejercicio' : 'Select a lift';
  String get historyNoData => _es ? 'Sin datos todavía' : 'No data yet';
  String historySets(int completed, int planned) =>
      _es ? '$completed / $planned series' : '$completed / $planned sets';
  String get historyMissedSets => _es ? 'series falladas' : 'missed sets';

  // Settings
  String get settingsTitle => _es ? 'Ajustes' : 'Settings';
  String get settingsUnits => _es ? 'Unidades' : 'Units';
  String get settingsLanguage => _es ? 'Idioma' : 'Language';
  String get settingsCoach => _es ? 'Coach IA' : 'AI coach';
  String get settingsCoachEnabled =>
      _es ? 'Activar coach IA' : 'Enable AI coach';
  String get settingsCoachUrl => _es ? 'URL del servidor' : 'Coach server URL';
  String get settingsCoachUrlHint => 'http://127.0.0.1:8080';
  String get settingsTestConnection =>
      _es ? 'Probar conexión' : 'Test connection';
  String get settingsConnectionOk => _es ? 'Conectado' : 'Connected';
  String get settingsConnectionFail => _es ? 'Sin conexión' : 'Not reachable';
  String get settingsIncrements => _es ? 'Incrementos (kg)' : 'Increments (kg)';
  String get settingsData => _es ? 'Datos' : 'Data';
  String get settingsReset =>
      _es ? 'Borrar todos los datos' : 'Delete all data';
  String get settingsResetConfirm => _es
      ? '¿Borrar todas las sesiones, planes y ajustes?'
      : 'Delete all sessions, plans and settings?';
  String get settingsExportBackup =>
      _es ? 'Exportar copia (JSON)' : 'Export backup (JSON)';
  String get settingsExportBackupBody => _es
      ? 'Ajustes, programa, sesiones y planes de coaching.'
      : 'Settings, program, sessions and coach plans.';
  String get settingsExportCsv =>
      _es ? 'Exportar sesiones (CSV)' : 'Export sessions (CSV)';
  String get settingsExportCsvBody => _es
      ? 'Una fila por serie, para Excel o Sheets.'
      : 'One row per set, for Excel or Sheets.';
  String get settingsImportBackup =>
      _es ? 'Importar copia (JSON)' : 'Import backup (JSON)';
  String get settingsImportBackupBody => _es
      ? 'Combinar o reemplazar los datos locales.'
      : 'Merge or replace the local data.';
  String get settingsBackupExported => _es ? 'Copia lista.' : 'Backup ready.';
  String get settingsBackupExportFailed =>
      _es ? 'No se pudieron exportar los datos' : 'Could not export the data';
  String get settingsImportTitle => _es ? 'Importar copia' : 'Import backup';
  String get settingsImportBody => _es
      ? 'Combinar conserva tus ajustes y programa actuales y añade o actualiza sesiones y planes. Reemplazar usa la copia para todo.'
      : 'Merge keeps your current settings and program and adds or updates sessions and coach plans. Replace uses the backup for everything.';
  String get settingsImportMerge => _es ? 'Combinar' : 'Merge';
  String get settingsImportReplace => _es ? 'Reemplazar' : 'Replace';
  String settingsImportDone(int sessions, int plans) => _es
      ? 'Importadas $sessions sesiones y $plans planes de coaching.'
      : 'Imported $sessions sessions and $plans coach plans.';
  String get settingsImportFailed =>
      _es ? 'No se pudo importar la copia' : 'Could not import the backup';
  String get settingsBackupWorking => _es ? 'Procesando…' : 'Working…';
  String get settingsAbout => _es ? 'Acerca de' : 'About';
  String get settingsVersion => _es ? 'Versión' : 'Version';
  String get settingsDisclaimer => _es ? 'Aviso médico' : 'Medical disclaimer';
  String get settingsProgram =>
      _es ? 'Programa de entrenamiento' : 'Training program';
  String get settingsProgramTemplate =>
      _es ? 'Plantilla de programa' : 'Program template';
  String settingsProgramWeek(int week) => _es ? 'Semana $week' : 'Week $week';
  String get settingsProgramTemplateConfirmTitle =>
      _es ? '¿Cambiar plantilla de programa?' : 'Switch program template?';
  String get settingsProgramTemplateConfirmBody => _es
      ? 'Esto reemplaza el programa actual con la plantilla seleccionada. Tu historial de sesiones se conserva.'
      : 'This replaces the current program with the selected template. Your session history is kept.';
  String get settingsProgramTemplateConfirmAction => _es ? 'Cambiar' : 'Switch';
  String settingsProgramTemplateApplied(String name) =>
      _es ? 'Ahora usas $name.' : 'Now using $name.';
  String programTemplateDescription(String id) {
    switch (id) {
      case '5_3_1':
        return _es
            ? 'Ondas 5/3/1 semanales con descarga cada cuatro semanas.'
            : 'Weekly 5/3/1 waves with a deload every fourth week.';
      case 'gzclp':
        return _es
            ? 'Progresión lineal T1/T2/T3 para los cuatro levantamientos principales.'
            : 'Linear T1/T2/T3 progression for the four main lifts.';
      case 'block_periodization':
        return _es
            ? 'Bloques de volumen, intensidad y descarga.'
            : 'Volume, intensity and deload blocks.';
      default:
        return _es ? 'Plantilla de cuatro días.' : 'A four-day template.';
    }
  }

  String get settingsAppearance => _es ? 'Apariencia' : 'Appearance';
  String get settingsDarkMode => _es ? 'Modo oscuro' : 'Dark mode';
  String get settingsSystemTheme => _es ? 'Sistema' : 'System';

  // Program
  String get programTitle => _es ? 'Programa' : 'Program';
  String get programMain => _es ? 'Principal' : 'Main';
  String get programVariation => _es ? 'Variación' : 'Variation';
  String get programAccessory => _es ? 'Accesorio' : 'Accessory';
  String get programReadOnly => _es
      ? 'Toca el lápiz para editar tu programa.'
      : 'Tap the pencil to edit your program.';
  String get programEditProgram => _es ? 'Editar programa' : 'Edit program';
  String get programProgramName => _es ? 'Nombre del programa' : 'Program name';
  String get programFocus => _es ? 'Enfoque' : 'Focus';
  String get programNoDays =>
      _es ? 'Añade un día para empezar.' : 'Add a day to get started.';
  String programCopyOf(String title) =>
      _es ? 'Copia de $title' : 'Copy of $title';
  String get programDayTitle => _es ? 'Título del día' : 'Day title';
  String get programExerciseName => _es ? 'Ejercicio' : 'Exercise';
  String get programRole => _es ? 'Rol' : 'Role';
  String get programAddDay => _es ? 'Añadir día' : 'Add day';
  String get programRemoveDay => _es ? 'Eliminar día' : 'Remove day';
  String get programAddExercise => _es ? 'Añadir ejercicio' : 'Add exercise';
  String get programRemoveExercise =>
      _es ? 'Eliminar ejercicio' : 'Remove exercise';
  String get programDuplicate => _es ? 'Duplicar' : 'Duplicate';
  String get programMoveUp => _es ? 'Subir' : 'Move up';
  String get programMoveDown => _es ? 'Bajar' : 'Move down';
  String get programEditSets => _es ? 'Editar series' : 'Edit sets';
  String programEditSetsTitle(String exercise) =>
      _es ? 'Editar series: $exercise' : 'Edit sets: $exercise';
  String get programNewDay => _es ? 'Día nuevo' : 'New day';
  String get programNewExercise => _es ? 'Ejercicio nuevo' : 'New exercise';
  String get programRestoreDefault =>
      _es ? 'Restaurar programa por defecto' : 'Restore default program';
  String get programRestoreDefaultConfirm => _es
      ? 'Esto reemplazará tu programa actual con el programa de 3 días. ¿Continuar?'
      : 'This will replace your current program with the seeded 3-day program. Continue?';
  String get programRestore => _es ? 'Restaurar' : 'Restore';
  String get programSave => _es ? 'Guardar programa' : 'Save program';
  String get programSaved => _es ? 'Programa guardado' : 'Program saved';
  String get programSaveFailed =>
      _es ? 'No se pudo guardar el programa.' : 'Could not save the program.';
  String get programDiscard => _es ? 'Descartar' : 'Discard';
  String get programStay => _es ? 'Seguir editando' : 'Keep editing';
  String get programUnsavedTitle =>
      _es ? 'Cambios sin guardar' : 'Unsaved changes';
  String get programUnsavedBody => _es
      ? '¿Descartar los cambios de este programa?'
      : 'Discard your edits to this program?';
  String get programDeleteDayTitle => _es ? 'Eliminar día' : 'Delete day';
  String programDeleteDayConfirm(String title) => _es
      ? '¿Eliminar "$title" y todos sus ejercicios?'
      : 'Delete "$title" and all its exercises?';
  String get programDeleteExerciseTitle =>
      _es ? 'Eliminar ejercicio' : 'Delete exercise';
  String programDeleteExerciseConfirm(String name) =>
      _es ? '¿Eliminar "$name"?' : 'Delete "$name"?';
  String get programNoMainLift => _es
      ? 'Este día no tiene un ejercicio principal.'
      : 'This day has no main lift.';
  String get programNoSets => _es ? 'Sin series' : 'No sets';
  String get programSet => _es ? 'Serie' : 'Set';
  String get programReps => _es ? 'Reps' : 'Reps';
  String get programRepsMax => _es ? 'Reps máx.' : 'Max reps';
  String get programLoad => _es ? 'Carga' : 'Load';
  String get programRpe => _es ? 'RPE máx.' : 'RPE cap';
  String get programAddSet => _es ? 'Añadir serie' : 'Add set';
  String get programRemoveSet => _es ? 'Eliminar serie' : 'Remove set';
  String get programDuplicateSet => _es ? 'Duplicar serie' : 'Duplicate set';
  String get programApply => _es ? 'Aplicar' : 'Apply';
  String get programValidationRequired => _es ? 'Obligatorio' : 'Required';
  String get programValidationInteger => _es ? 'Número entero' : 'Whole number';
  String get programValidationDecimal =>
      _es ? 'Número inválido' : 'Invalid number';
  String get programValidationRange =>
      _es ? 'Entre 1 y 100' : 'Between 1 and 100';
  String get programValidationRepsMax =>
      _es ? 'Debe ser ≥ reps' : 'Must be ≥ reps';
  String get programValidationLoadRange =>
      _es ? 'Carga fuera de rango' : 'Load out of range';
  String get programValidationRpeRange =>
      _es ? 'RPE entre 1 y 10' : 'RPE between 1 and 10';
  String get programValidationNoDays => _es
      ? 'El programa necesita al menos un día.'
      : 'The program needs at least one day.';
  String get programValidationDayTitle => _es
      ? 'El título del día no puede estar vacío.'
      : 'Day title cannot be empty.';
  String get programValidationExerciseName => _es
      ? 'El nombre del ejercicio no puede estar vacío.'
      : 'Exercise name cannot be empty.';
  String get programValidationDuplicateId => _es
      ? 'Hay identificadores duplicados en el programa.'
      : 'The program contains duplicate identifiers.';
  String programValidationExercise(String name) =>
      _es ? 'Revisa las series de $name.' : 'Check the sets for $name.';
  String get setsLabel => _es ? 'series' : 'sets';
  String signedSets(int delta) {
    final single = delta.abs() == 1;
    if (_es) {
      return '${delta > 0 ? '+' : ''}$delta ${single ? 'serie' : 'series'}';
    }
    return '${delta > 0 ? '+' : ''}$delta ${single ? 'set' : 'sets'}';
  }

  String signedPercent(double value) {
    final rounded = value.roundToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${value > 0 ? '+' : ''}$rounded%';
  }

  String get thisWeek => _es ? 'Esta semana' : 'This week';
  String sessionsCount(int value) => _es
      ? '$value ${value == 1 ? 'sesión' : 'sesiones'}'
      : '$value ${value == 1 ? 'session' : 'sessions'}';
  String get errorGeneric => _es ? 'Algo salió mal.' : 'Something went wrong.';
  String get coachOfflineHint => _es
      ? 'Funciona sin conexión. La IA es opcional.'
      : 'Works offline. AI is optional.';
  String get settingsCoachHint => _es
      ? 'El servidor guarda tu clave; la app nunca la ve.'
      : 'The server holds your key; the app never sees it.';
  String get settingsCoachToken => _es ? 'Token de acceso' : 'Access token';
  String get settingsCoachTokenHint =>
      _es ? 'Token para el servidor de coaching' : 'Coach server access token';
  String get settingsCoachTokenShow => _es ? 'Mostrar' : 'Show';
  String get settingsCoachTokenHide => _es ? 'Ocultar' : 'Hide';

  String dayTitle(String dayId, String title) {
    if (title.isNotEmpty) {
      return title;
    }
    const en = <String, String>{
      'day-1': 'Squat & Lower Body',
      'day-2': 'Bench & Upper Body',
      'day-3': 'Deadlift & Shoulders',
    };
    const es = <String, String>{
      'day-1': 'Sentadilla y tren inferior',
      'day-2': 'Banca y tren superior',
      'day-3': 'Peso muerto y hombros',
    };
    return (_es ? es : en)[dayId] ?? dayId;
  }

  String dayShort(String dayId) {
    const en = <String, String>{
      'day-1': 'Day 1',
      'day-2': 'Day 2',
      'day-3': 'Day 3',
    };
    const es = <String, String>{
      'day-1': 'Día 1',
      'day-2': 'Día 2',
      'day-3': 'Día 3',
    };
    return (_es ? es : en)[dayId] ?? dayId;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .map((supported) => supported.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
