import 'package:sembast/sembast.dart';

Future<Database> openDatabaseForPlatform() {
  throw UnsupportedError('No database implementation for this platform');
}
