import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app/sourcebase_app.dart';
import 'features/auth/data/sourcebase_auth_backend.dart';

SemanticsHandle? _sourceBaseSemanticsHandle;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _sourceBaseSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
  await SourceBaseAuthBackend.initialize();
  runApp(const SourceBaseApp());
}
