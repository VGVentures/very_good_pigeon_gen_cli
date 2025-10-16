import 'package:my_plugin_platform_interface/src/classes/classes.g.dart';
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'my_plugin_android',
    kotlinOptions: KotlinOptions(),
    kotlinOut: 'android/src/main/kotlin/com/example/verygoodcore/Messages.g.kt',
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

// <!-- start pigeonGenBaseClasses -->
const List<Type> baseClasses = [
  TestEnum,
  TestModel2,
  TestEnum1,
  TestModel,
  TestModel3,
];

// <!-- end pigeonGenBaseClasses -->
