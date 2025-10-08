import 'package:my_plugin_platform_interface/src/models/models.dart';

/// A model representing test data and its associated [TestEnum] value.
class TestModel3 {
  /// Creates a [TestModel3] with the given [data] and [enumValue].
  const TestModel3({required this.data, required this.enumValue});

  /// The data string for this model.
  final String data;

  /// The enum value associated with this model.
  final TestEnum enumValue;
}
