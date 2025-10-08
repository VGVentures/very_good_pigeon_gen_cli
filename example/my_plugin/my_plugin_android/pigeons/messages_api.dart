import 'package:my_plugin_platform_interface/src/models/models.dart';
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    javaOptions: JavaOptions(package: 'io.flutter.plugins.urllauncher'),
    javaOut:
        'android/src/main/java/io/flutter/plugins/urllauncher/Messages.java',
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@HostApi()
abstract class Messages {
  TestModel getTestModel(TestModel2 model);

  void testVoid();

  Response getResponse();
}

/// Response class
class Response {
  Response({required this.model});

  final TestModel2 model;
}
