import 'package:flutter_test/flutter_test.dart';

import 'src/availability.dart' as availability;
import 'src/cupertino_foundation_models.dart' as facade;
import 'src/errors.dart' as errors;
import 'src/file_selection.dart' as file_selection;
import 'src/generation.dart' as generation;
import 'src/platform/method_channel_cupertino_foundation_models.dart'
    as method_channel;
import 'src/schema.dart' as schema;
import 'src/session.dart' as session;
import 'src/tools.dart' as tools;
import 'src/transcription.dart' as transcription;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  availability.main();
  errors.main();
  file_selection.main();
  generation.main();
  schema.main();
  session.main();
  tools.main();
  transcription.main();
  facade.main();
  method_channel.main();
}
