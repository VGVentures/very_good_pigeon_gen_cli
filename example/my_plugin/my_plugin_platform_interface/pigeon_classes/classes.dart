/// An enum representing test values.
enum TestEnum {
  /// The first value.
  value1,

  /// The second value.
  value2,

  /// The third value.
  value3,
}

/// A model representing test data and its associated [TestModel3] model.
class TestModel2 {
  /// Creates a [TestModel2] with the given [data] and [model].
  const TestModel2({required this.data, required this.model});

  /// The data string for this model.
  final String data;

  /// The model associated with this model.
  final TestModel3 model;
}

/// An enum representing test values.
enum TestEnum1 {
  /// The first value.
  value1,

  /// The second value.
  value2,

  /// The third value.
  value3,
}

/// A model representing test data and its associated [TestModel3] model.
class TestModel {
  /// Creates a [TestModel] with the given [data], [model], and [enumValue].
  const TestModel({
    required this.data,
    required this.model,
    required this.enumValue,
  });

  /// The data string for this model.
  final String data;

  /// The model associated with this model.
  final TestModel3 model;

  /// The enum value associated with this model.
  final TestEnum1 enumValue;
}

/// A model representing test data and its associated [TestEnum] value.
class TestModel3 {
  /// Creates a [TestModel3] with the given [data] and [enumValue].
  const TestModel3({required this.data, required this.enumValue});

  /// The data string for this model.
  final String data;

  /// The enum value associated with this model.
  final TestEnum enumValue;
}
