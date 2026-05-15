import 'package:flutter/material.dart';

import 'app/sourcebase_app.dart';
import 'features/auth/data/sourcebase_auth_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SourceBaseAuthBackend.initialize();
  runApp(const SourceBaseApp());
}
