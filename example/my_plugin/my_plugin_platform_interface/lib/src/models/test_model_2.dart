import 'package:my_plugin_platform_interface/src/models/test_model_3.dart';

/// A model representing test data and its associated [TestModel3] model.
class TestModel2 {
  /// Creates a [TestModel2] with the given [data] and [model].
  const TestModel2({required this.data, required this.model});

  /// The data string for this model.
  final String data;

  /// The model associated with this model.
  final TestModel3 model;
}
