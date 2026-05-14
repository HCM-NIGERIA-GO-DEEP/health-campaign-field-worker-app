class ActionConfig {
  final String action;
  final String actionType;
  final Map<dynamic, dynamic> properties;
  final Map<String, dynamic>? condition;
  final List<ActionConfig>? actions;

  ActionConfig({
    required this.action,
    required this.actionType,
    required this.properties,
    this.condition,
    this.actions,
  });

  factory ActionConfig.fromJson(Map<String, dynamic> json) {
    List<ActionConfig>? actions;
    if (json['actions'] != null) {
      actions = (json['actions'] as List)
          .map((actionJson) => ActionConfig.fromJson(actionJson))
          .toList();
    }

    return ActionConfig(
      action: json['action'] ?? '',
      actionType: json['actionType'] ?? '',
      properties: json['properties'] ?? {},
      condition: json['condition'],
      actions: actions,
    );
  }

  ActionConfig copyWith({
    String? action,
    String? actionType,
    Map<dynamic, dynamic>? properties,
    Map<String, dynamic>? condition,
    List<ActionConfig>? actions,
  }) {
    return ActionConfig(
      action: action ?? this.action,
      actionType: actionType ?? this.actionType,
      properties: properties ?? this.properties,
      condition: condition ?? this.condition,
      actions: actions ?? this.actions,
    );
  }
}
