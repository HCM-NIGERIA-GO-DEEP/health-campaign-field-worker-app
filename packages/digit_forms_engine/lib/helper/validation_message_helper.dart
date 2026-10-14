import 'package:digit_forms_engine/utils/utils.dart';

import '../blocs/app_localization.dart';
import '../models/property_schema/property_schema.dart';

/// Translates each rule.message via [localize].
Map<String, String Function(Object)> buildValidationMessages(
  List<ValidationRule>? validations,
  dynamic localize,
) {
  final Map<String, String Function(Object)> messages = {};

  if (validations == null) return messages;

  for (final rule in validations) {
    if (rule.message == null) continue;

    // first translate the message, or use the message as-is if translation returns null
    final translated = translateIfPresent(rule.message, localize) ??
        rule.message ??
        localize.translate("FIELD_VALIDATION_ERROR");

    // Ensure translated is not empty - if it is, use the rule type as fallback
    final finalMessage = (translated.trim().isNotEmpty)
        ? translated
        : rule.type;

    switch (rule.type) {
      case 'required':
        messages['required'] = (_) => finalMessage;
        break;
      case 'minLength':
        messages['minLength'] = (_) => finalMessage;
        break;
      case 'maxLength':
        messages['maxLength'] = (_) => finalMessage;
        break;
      case 'min':
      case 'minValue':
        messages['min'] = (_) => finalMessage;
        break;
      case 'max':
      case 'maxValue':
        messages['max'] = (_) => finalMessage;
        break;
      case 'pattern':
        messages['pattern'] = (_) => finalMessage;
        break;
      case 'regex':
        messages['regex'] = (_) => finalMessage;
        break;
      case 'notEqualTo':
        messages['notEqualTo'] = (_) => finalMessage;
        break;
      case 'maxField':
        messages['maxField'] = (_) => finalMessage;
        break;
      case 'scanLimit':
        messages['scanLimit'] = (_) => translated;
        break;
      case 'isGS1':
        messages['isGS1'] = (_) => translated;
        break;
      case 'conditionalPattern':
        // The validator's error payload carries which case matched (and
        // therefore which message applies), since a single field can have
        // several possible expected formats depending on a sibling field -
        // rule.message here is only the fallback if that lookup comes up
        // empty.
        messages['conditionalPattern'] = (error) {
          if (error is Map) {
            final key = error['messageKey'];
            if (key is String && key.isNotEmpty) {
              final caseTranslated = translateIfPresent(key, localize);
              if (caseTranslated != null && caseTranslated.trim().isNotEmpty) {
                return caseTranslated;
              }
              return key;
            }
          }
          return finalMessage;
        };
        break;
      default:
        break;
    }
  }

  return messages;
}
