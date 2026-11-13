import 'package:sembast/sembast.dart';

import 'opener_stub.dart'
    if (dart.library.io) 'opener_io.dart'
    if (dart.library.js_interop) 'opener_web.dart'
    as impl;

/// Opens the platform database (sembast IO on mobile/desktop, IndexedDB on web).
Future<Database> openPlatformDatabase() => impl.openDatabaseForPlatform();
