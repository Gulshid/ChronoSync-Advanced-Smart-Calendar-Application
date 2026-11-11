class CalendarModel {
  const CalendarModel({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isVisible = true,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool isVisible;
  final bool isDefault;
  final int sortOrder;

  CalendarModel copyWith({String? name, int? colorValue, bool? isVisible, int? sortOrder}) {
    return CalendarModel(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isVisible: isVisible ?? this.isVisible,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': colorValue,
        'is_visible': isVisible ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory CalendarModel.fromMap(Map<String, Object?> m) => CalendarModel(
        id: m['id'] as String,
        name: m['name'] as String,
        colorValue: m['color'] as int,
        isVisible: (m['is_visible'] as int) == 1,
        isDefault: (m['is_default'] as int) == 1,
        sortOrder: m['sort_order'] as int,
      );
}
