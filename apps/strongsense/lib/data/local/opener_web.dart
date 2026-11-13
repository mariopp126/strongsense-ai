import 'package:sembast_web/sembast_web.dart';

Future<Database> openDatabaseForPlatform() =>
    databaseFactoryWeb.openDatabase('strongsense.db');
