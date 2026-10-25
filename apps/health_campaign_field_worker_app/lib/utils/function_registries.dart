import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:digit_crud_bloc/digit_crud_bloc.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/entities/roles_type.dart';
import 'utils.dart';

class FunctionRegistries {
  final BuildContext context;

  FunctionRegistries(this.context);

  void registerAll() {
    _registerGenerateFunctions();
    _registerInventoryFunctions();
    _registerTransactionFunctions();
    _registerFacilityFunctions();
    _registerStockFunctions();
    _registerRoleFunctions();
    _registerViewTransactionFunctions();
  }

  void _registerGenerateFunctions() {
    // For report fields that display a quantity while the stored sign is
    // retained for stock calculations.
    FunctionRegistry.register('absoluteValue', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';

      final raw = args.first;
      final number = raw is num ? raw : num.tryParse(raw.toString().trim());
      if (number == null) return raw.toString();

      final absolute = number.abs();
      return absolute == absolute.roundToDouble() ? absolute.toInt() : absolute;
    });

    // Checks if the number of registered under-5 children in the household matches
    // the expected children count (childrenCount) entered in household details.
    // Returns true (mismatch) if counts differ (e.g. to disable the backToSearchRegistrar button),
    // false if they match.
    FunctionRegistry.register('isUnder5CountMismatch', (args, stateData) {
      if (args.isEmpty) return false;

      final membersArg = args.first;
      List<dynamic> membersList = [];
      if (membersArg is List) {
        membersList = membersArg;
      } else if (membersArg is Map) {
        membersList = [membersArg];
      }

      int expectedCount = 0;
      bool foundExpectedCount = false;

      int? extractChildrenCount(dynamic obj) {
        if (obj == null) return null;
        if (obj is num) return obj.toInt();
        if (obj is String) {
          final parsed = int.tryParse(obj.trim());
          if (parsed != null) return parsed;
        }
        if (obj is List && obj.isNotEmpty) {
          for (final item in obj) {
            final count = extractChildrenCount(item);
            if (count != null) return count;
          }
          return null;
        }

        // Direct property check if it has childrenCount
        if (obj is Map) {
          if (obj.containsKey('childrenCount')) {
            final val = obj['childrenCount'];
            final parsed = val is num ? val.toInt() : int.tryParse(val?.toString().trim() ?? '');
            if (parsed != null) return parsed;
          }
          if (obj.containsKey('HouseholdModel')) {
            final parsed = extractChildrenCount(obj['HouseholdModel']);
            if (parsed != null) return parsed;
          }
        } else {
          try {
            final val = (obj as dynamic).childrenCount;
            if (val != null) {
              final parsed = val is num ? val.toInt() : int.tryParse(val.toString().trim());
              if (parsed != null) return parsed;
            }
          } catch (_) {}
        }

        // Check additionalFields
        dynamic af;
        try {
          af = (obj as dynamic).additionalFields;
        } catch (_) {}
        if (af == null && obj is Map) {
          af = obj['additionalFields'];
        }

        if (af != null) {
          if (af is Map) {
            if (af.containsKey('childrenCount')) {
              final val = af['childrenCount'];
              final parsed = val is num ? val.toInt() : int.tryParse(val?.toString().trim() ?? '');
              if (parsed != null) return parsed;
            }
          } else {
            try {
              final val = (af as dynamic).childrenCount;
              if (val != null) {
                final parsed = val is num ? val.toInt() : int.tryParse(val.toString().trim());
                if (parsed != null) return parsed;
              }
            } catch (_) {}
          }

          dynamic fields;
          try {
            fields = af.fields;
          } catch (_) {}
          if (fields == null && af is Map) {
            fields = af['fields'];
          }
          if (fields is List) {
            for (final f in fields) {
              if (f == null) continue;
              final key = f is Map ? f['key'] : (f as dynamic).key;
              final val = f is Map ? f['value'] : (f as dynamic).value;
              if (key == 'childrenCount') {
                final parsed = val is num ? val.toInt() : int.tryParse(val?.toString().trim() ?? '');
                if (parsed != null) return parsed;
              }
            }
          }
        }
        return null;
      }

      if (args.length > 1) {
        final parsed = extractChildrenCount(args[1]);
        if (parsed != null) {
          expectedCount = parsed;
          foundExpectedCount = true;
        }
      }

      // Fallback to stateData if expectedCount was not found from args
      if (!foundExpectedCount && stateData != null) {
        final hhFromState = stateData.modelMap['HouseholdModel'] ??
            stateData.modelMap['household'] ??
            (stateData.rawState is Map ? (stateData.rawState as Map)['household'] : null);
        final parsed = extractChildrenCount(hhFromState);
        if (parsed != null) {
          expectedCount = parsed;
          foundExpectedCount = true;
        }
      }

      int registeredCount = 0;
      for (final item in membersList) {
        if (item == null) continue;
        dynamic memberObj;
        if (item is Map) {
          memberObj = item['member'] ?? item['members'] ?? item['householdMember'] ?? item;
        } else {
          try {
            memberObj = (item as dynamic).member ?? (item as dynamic).members ?? (item as dynamic).householdMember ?? item;
          } catch (_) {
            memberObj = item;
          }
        }

        bool isHead = false;
        if (memberObj is List) {
          for (final m in memberObj) {
            if (m == null) continue;
            final headVal = m is Map ? m['isHeadOfHousehold'] : (m as dynamic).isHeadOfHousehold;
            if (headVal == true || headVal?.toString().toLowerCase() == 'true' || headVal == 1) {
              isHead = true;
              break;
            }
          }
        } else if (memberObj != null) {
          final headVal = memberObj is Map ? memberObj['isHeadOfHousehold'] : (memberObj as dynamic).isHeadOfHousehold;
          if (headVal == true || headVal?.toString().toLowerCase() == 'true' || headVal == 1) {
            isHead = true;
          }
        }

        if (!isHead) {
          registeredCount++;
        }
      }

      return registeredCount != expectedCount;
    });

    // Displays whole-number decimals without the trailing .0 while
    // preserving non-whole values (e.g. 4.0 -> 4, 4.1 -> 4.1).
    FunctionRegistry.register('trimTrailingZero', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';

      final raw = args.first;
      final number = raw is num ? raw : num.tryParse(raw.toString().trim());

      if (number == null) return raw.toString();
      return number == number.roundToDouble() ? number.toInt() : number;
    });

    // Clamps a dose-criteria-configured number to a maximum (defaulting to
    // maxDeliveryQuantityPerHousehold), formatting it the same way
    // trimTrailingZero does. Used anywhere a displayed ITN quantity is read
    // directly from project config, bypassing the ResourceCard widget that
    // enforces this same cap on the quantity actually entered for delivery.
    // Usage: "{{fn:capNumber(path.to.quantity, 3)}}"
    FunctionRegistry.register('capNumber', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';

      final raw = args.first;
      final number = raw is num ? raw : num.tryParse(raw.toString().trim());
      if (number == null) return raw.toString();

      final maxArg = args.length > 1 ? args[1] : null;
      final max = maxArg is num
          ? maxArg
          : num.tryParse(maxArg?.toString() ?? '') ??
              maxDeliveryQuantityPerHousehold;

      final capped = number > max ? max : number;
      return capped == capped.roundToDouble() ? capped.toInt() : capped;
    });

    // Resolves the ITN entitlement for a household from its member count,
    // per the project type's taskProcedure ("1 bednet per 2 household
    // members", capped at maxDeliveryQuantityPerHousehold).
    //
    // This deliberately does NOT read the dose criteria's `quantity`: that
    // is a flat per-unit "1" in the project type config, so using it showed
    // the same figure for a 1-member and a 7-member household - and it
    // resolved to an empty string entirely whenever no cycle was currently
    // running, since the whole targetCycle lookup collapsed to null.
    // Usage: "{{fn:itnsForMemberCount(path.to.memberCount)}}"
    FunctionRegistry.register('itnsForMemberCount', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';

      final raw = args.first;
      final memberCount =
          raw is num ? raw.toInt() : int.tryParse(raw.toString().trim());

      final quantity = itnQuantityForMemberCount(memberCount);

      return quantity?.toString() ?? '';
    });

    FunctionRegistry.register('safeString', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';

      final value = args.first.toString();
      final trimmed = value.trim();

      if (trimmed.isEmpty) return '';

      // Some unresolved templates can leak through as literal strings.
      if (trimmed.contains('{{') && trimmed.contains('}}')) return '';

      return value;
    });

    FunctionRegistry.register('getCommentValue', (args, stateData) {
      if (args.isEmpty || args.first == null) return null;

      final value = args.first.toString();
      final trimmed = value.trim();

      if (trimmed.isEmpty) return null;

      return value;
    });

    FunctionRegistry.register('generateUniqueMaterialNoteNumber',
        (args, stateData) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String userUuid = context.loggedInUserUuid;
      String combinedId = '$userUuid$timestamp';
      List<int> bytes = utf8.encode(combinedId);
      Digest sha256Hash = sha256.convert(bytes);
      String hashString = sha256Hash.toString();
      String uniqueId = hashString.substring(0, 12).toUpperCase();
      String formattedUniqueId = uniqueId.replaceAllMapped(
        RegExp(r'.{1,4}'),
        (match) => '${match.group(0)}-',
      );
      formattedUniqueId =
          formattedUniqueId.substring(0, formattedUniqueId.length - 1);
      if (kDebugMode) {
        print('uniqueId : $formattedUniqueId');
      }
      return formattedUniqueId;
    });
  }

  void _registerInventoryFunctions() {
    FunctionRegistry.register('bottlesToMl', (args, stateData) {
      if (args.isEmpty) return 0;
      final raw = args.first;
      final bottles =
          (raw is num) ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
      return bottles * 30;
    });

    FunctionRegistry.register('mlToBottles', (args, stateData) {
      if (args.isEmpty) return 0;
      final raw = args.first;
      final ml = (raw is num) ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
      final bottles = ml / 30;
      final rounded = bottles.roundToDouble();
      return bottles == rounded ? rounded.toInt() : bottles;
    });

    FunctionRegistry.register('getQuantityLabel', (args, stateData) {
      if (args.isEmpty) return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
      final sku = args.first?.toString() ?? '';
      if (sku.trim().toString() == 'SPAQ - 250 mg' ||
          sku.trim().toString() == 'SPAQ - 500 mg') {
        return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
      }
      return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
    });

    FunctionRegistry.register('getStockQuantityLabel', (args, stateData) {
      if (args.isEmpty) return 'APPONE_INVENTORY_QUANTITY_LABEL';
      final source = args.first;
      var entryType = '';
      if (source is List) {
        for (final field in source) {
          if (field is Map && field['key']?.toString() == 'stockEntryType') {
            entryType = field['value']?.toString() ?? '';
            break;
          }
          try {
            final dynamic typedField = field;
            if (typedField.key?.toString() == 'stockEntryType') {
              entryType = typedField.value?.toString() ?? '';
              break;
            }
          } catch (_) {
            // Ignore fields that do not expose the additional-field shape.
          }
        }
      } else {
        entryType = source?.toString() ?? '';
      }
      final stockEntryType = entryType.toUpperCase();
      const labels = {
        'RECEIPT': 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL',
        'RETURNED': 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL',
        'ISSUED': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'DISPATCH': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'LOSS': 'APPONE_INVENTORY_QUANTITY_LOST_LABEL',
        'DAMAGED': 'APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL'
      };
      return labels[stockEntryType] ?? 'APPONE_INVENTORY_QUANTITY_LABEL';
    });

    // The view-transaction-details screen's "heading" is only ever a plain
    // {{navigation.x}} substitution followed by translate() - it can't branch
    // on its own (see _resolveHeading in layout_renderer.dart), so the
    // config resolves the final heading CODE here, while stockEntryType is
    // still in scope, and carries it through navigation as plain data.
    FunctionRegistry.register('getViewTransactionHeadingCode',
        (args, stateData) {
      if (args.isEmpty) return 'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
      final source = args.first;
      var entryType = '';
      if (source is List) {
        for (final field in source) {
          if (field is Map && field['key']?.toString() == 'stockEntryType') {
            entryType = field['value']?.toString() ?? '';
            break;
          }
          try {
            final dynamic typedField = field;
            if (typedField.key?.toString() == 'stockEntryType') {
              entryType = typedField.value?.toString() ?? '';
              break;
            }
          } catch (_) {
            // Ignore fields that do not expose the additional-field shape.
          }
        }
      } else if (source is Map) {
        entryType = source['stockEntryType']?.toString() ?? '';
      } else {
        entryType = source?.toString() ?? '';
      }
      final stockEntryType = entryType.toUpperCase();
      const headings = {
        'ISSUED': 'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
        'RETURNED': 'INVENTORY_STOCK_RETURN_DETAILS_HEADING',
        'DAMAGED': 'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING',
        'LOSS': 'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
      };
      return headings[stockEntryType] ??
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
    });

    FunctionRegistry.register('getReportTitle', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      const titles = {
        'receipt': 'INVENTORY_REPORT_DETAILS_RECEIPT_REPORT_TITLE',
        'dispatch': 'INVENTORY_REPORT_DETAILS_DISPATCH_REPORT_TITLE',
        'returned': 'INVENTORY_REPORT_DETAILS_RETURNED_REPORT_TITLE',
        'damage': 'INVENTORY_REPORT_DETAILS_DAMAGE_REPORT_TITLE',
        'loss': 'INVENTORY_REPORT_DETAILS_LOSS_REPORT_TITLE',
        'reconciliation': 'INVENTORY_REPORT_DETAILS_RECONCILIATION_REPORT_TITLE'
      };
      return titles[reportType] ?? '';
    });

    FunctionRegistry.register('getTransactingPartyLabel', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      const labels = {
        'receipt': 'INVENTORY_REPORT_DETAILS_RECEIPT_TRANSACTING_PARTY_LABEL',
        'dispatch': 'INVENTORY_REPORT_DETAILS_DISPATCH_TRANSACTING_PARTY_LABEL',
        'returned': 'INVENTORY_REPORT_DETAILS_RETURNED_TRANSACTING_PARTY_LABEL',
        'damage': 'INVENTORY_REPORT_DETAILS_DAMAGED_TRANSACTING_PARTY_LABEL',
        'loss': 'INVENTORY_REPORT_DETAILS_LOSS_TRANSACTING_PARTY_LABEL'
      };
      return labels[reportType] ?? '';
    });

    FunctionRegistry.register('getTransactingParty', (args, stateData) {
      if (args.length < 2) return '';
      final reportType = args[0]?.toString() ?? '';
      final item = args[1];
      if (item == null) return '';
      if (reportType == 'dispatch') {
        return item['receiverId']?.toString() ??
            item['receiverType']?.toString() ??
            '';
      }
      return item['senderId']?.toString() ??
          item['senderType']?.toString() ??
          '';
    });
  }

  void _registerTransactionFunctions() {
    FunctionRegistry.register('getTransactionType', (args, stateData) {
      if (args.isEmpty) return [];
      final reportType = args.first?.toString() ?? '';
      const types = {
        'receipt': ['RECEIVED'],
        'dispatch': ['DISPATCHED'],
        'returned': ['RECEIVED'],
        'damage': ['DISPATCHED'],
        'loss': ['DISPATCHED']
      };
      return types[reportType] ?? [];
    });

    FunctionRegistry.register('getTransactionReason', (args, stateData) {
      if (args.isEmpty) return [];
      final stockEntryType = args.first?.toString().toUpperCase() ?? '';
      const reasons = {
        'RECEIPT': ['RECEIVED'],
        'ISSUED': ['DISPATCHED'],
        'RETURNED': ['RETURNED'],
        'DAMAGED': ['DAMAGED_IN_STORAGE', 'DAMAGED_IN_TRANSIT'],
        'LOSS': ['LOST_IN_STORAGE', 'LOST_IN_TRANSIT'],
      };
      return reasons[stockEntryType] ?? [];
    });

    FunctionRegistry.register('getStockEntryType', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      const entryTypes = {
        'receipt': 'RECEIPT',
        'dispatch': 'ISSUED',
        'returned': 'RETURNED',
        'damage': 'DAMAGED',
        'loss': 'LOSS',
        'excess': 'EXCESS',
        'less': 'LESS',
      };
      // Distributor loss declarations are persisted as LESS adjustments.
      if (reportType == 'loss' && isDistributor) return 'LESS';
      return entryTypes[reportType] ?? '';
    });

    FunctionRegistry.register('getSenderOrReceiver', (args, stateData) {
      if (args.isEmpty) return 'receiverId';
      final reportType = args.first?.toString() ?? '';
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      // Distributor LESS adjustments may be linked to a facility in either
      // party field, or recorded by the distributor's UUID. Other damage/loss
      // records are facility-scoped but can be on either side of a movement.
      if (isDistributor && (reportType == 'damage' || reportType == 'loss')) {
        return 'senderId,receiverId,clientCreatedBy';
      }
      if (reportType == 'damage' || reportType == 'loss') {
        return 'senderId,receiverId';
      }
      const senderTypes = {
        'dispatch',
        'damage',
        'loss',
        'returned',
        'less',
        'excess'
      };
      return senderTypes.contains(reportType) ? 'senderId' : 'receiverId';
    });

    FunctionRegistry.register('getReportFacilityId', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      if (isDistributor) return context.loggedInUserUuid ?? '';
      return args.length > 1 ? args[1]?.toString() ?? '' : '';
    });

    FunctionRegistry.register('getAuditFilterKey', (args, stateData) {
      if (args.isEmpty) return 'clientCreatedBy';
      final reportType = args.first?.toString() ?? '';
      return reportType == 'receipt' ? 'clientModifiedBy' : 'clientCreatedBy';
    });

    // Distributors have no one below them to issue stock to, so the
    // Issued/Returned selection screen should only offer Returned for them.
    FunctionRegistry.register('getIssueReturnOptions', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());

      final options = [
        {
          'name': 'APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_ISSUED',
          'code': 'ISSUED',
        },
        {
          'name': 'APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_RETURNED',
          'code': 'RETURNED',
        },
      ];

      return isDistributor
          ? options.where((o) => o['code'] == 'RETURNED').toList()
          : options;
    });

    FunctionRegistry.register('getSecondaryType', (args, stateData) {
      if (args.isEmpty) return 'WAREHOUSE';
      final facilityFromWhich = args.first?.toString() ?? '';
      return facilityFromWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
    });

    // INVENTORY.json calls fn:getStockSenderId / fn:getStockReceiverId when
    // fetching the "stock" transformer context, but neither was registered,
    // so FunctionRegistry.call returned null for both (same failure mode
    // already documented above for getStockTeamCode). The actual StockModel
    // senderId/receiverId mapping in transformer_config.dart doesn't consume
    // these two context keys, so this wasn't the direct cause of the return
    // quantity bug - but it's still a silently-failing config reference, so
    // it's implemented here to mirror the real senderId/receiverId mapping
    // (transformer_config.dart's senderPartyType/receiverPartyType switch)
    // in case anything else starts depending on these context keys.
    //
    // args (sender): [stockEntryType, primaryRole, facilityFromWhich,
    //                 warehouseTeamCode, deliveryTeam, loggedInUserUuid]
    FunctionRegistry.register('getStockSenderId', (args, stateData) {
      if (args.length < 6) return '';
      final facilityFromWhich = args[2]?.toString() ?? '';
      final loggedInUserUuid = args[5]?.toString() ?? '';
      final senderPartyType =
          facilityFromWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
      return senderPartyType == 'STAFF' ? loggedInUserUuid : facilityFromWhich;
    });

    // args (receiver): [stockEntryType, primaryRole, facilityToWhich,
    //                    warehouseTeamCode, deliveryTeam]
    FunctionRegistry.register('getStockReceiverId', (args, stateData) {
      if (args.length < 4) return '';
      final facilityToWhich = args[2]?.toString() ?? '';
      final teamCode = args[3]?.toString() ?? '';
      final receiverPartyType =
          facilityToWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
      return receiverPartyType == 'STAFF' ? teamCode : facilityToWhich;
    });

    FunctionRegistry.register('getTeamCode', (args, stateData) {
      if (args.isEmpty) return '';
      final teamCode = args.first?.toString() ?? '';
      if (teamCode.contains("||")) {
        return teamCode.split("||").last.trim();
      }
      return teamCode;
    });

    // Resolves the delivery team a stock transaction is addressed to.
    //
    // The "stock" transformer config maps
    //   receiverId -> __switch:receiverPartyType{STAFF: __context:teamCode, ...}
    // so whenever the receiving party is a delivery team, receiverId is exactly
    // whatever this returns. INVENTORY.json called this function but it was
    // never registered, and FunctionRegistry.call returns null for an unknown
    // name (rendered as ''), so every delivery-team receipt was saved with no
    // receiver at all.
    //
    // Prefer the scanned destination team for Delivery To. For returns where
    // the source is a delivery team, use the separately scanned source code.
    //
    // args: [stockEntryType, primaryRole, warehouseDetails.teamCode,
    //        warehouseDetails.facilityToWhich, stockDetails.facilityFromWhich,
    //        stockDetails.deliveryTeam]
    FunctionRegistry.register('getStockTeamCode', (args, stateData) {
      String argAt(int index) =>
          args.length > index ? (args[index]?.toString().trim() ?? '') : '';

      final destinationTeam = argAt(2);
      final sourceTeam = argAt(5);
      final rawTeam = argAt(3) == 'DELIVERY_TEAM'
          ? destinationTeam
          : (argAt(4) == 'DELIVERY_TEAM' ? sourceTeam : '');
      if (rawTeam.isEmpty) return '';

      // A scanned team QR arrives as "userName||userUuid" (see getTeamCode), so
      // strip the name - receiverId has to be the bare uuid. A team code filled
      // in from the logged-in distributor has no separator and passes through.
      return rawTeam.contains('||') ? rawTeam.split('||').last.trim() : rawTeam;
    });

    // Extracts the userName (part before "||") from the scanned team QR
    // ("userName||userUuid"). Returns '' when no userName is present
    // (e.g. when the scanned QR only contains the userUuid).
    FunctionRegistry.register('getTeamName', (args, stateData) {
      if (args.isEmpty) return '';
      final teamCode = args.first?.toString() ?? '';
      if (teamCode.contains("||")) {
        return teamCode.split("||").first.trim();
      }
      return '';
    });

    // Resolves the delivery-team (CDD) name to persist on a stock transaction,
    // for whichever side the team is on:
    // - Issue (team is the RECEIVER): the team QR is scanned into teamCode as
    //   "userName||userUuid" -> use that userName.
    // - Return (team is the SENDER): senderId is the logged-in user's uuid
    //   (see the transformer senderId mapping), so the matching name is the
    //   logged-in user's name, passed in from context.
    // - Warehouse <-> warehouse: '' (no staff party involved).
    // args: [teamCode, facilityFromWhich, loggedInUserName]
    FunctionRegistry.register('getDeliveryTeamName', (args, stateData) {
      final teamCode = args.isNotEmpty ? (args[0]?.toString() ?? '') : '';
      if (teamCode.contains("||")) {
        return teamCode.split("||").first.trim();
      }
      final facilityFromWhich =
          args.length > 1 ? (args[1]?.toString() ?? '') : '';
      if (facilityFromWhich == 'DELIVERY_TEAM') {
        return args.length > 2 ? (args[2]?.toString() ?? '') : '';
      }
      return '';
    });

    FunctionRegistry.register('getTransactionStatusType', (args, stateData) {
      if (args.isEmpty) return 'default';
      final transactionType = args.first?.toString().toUpperCase() ?? '';
      switch (transactionType) {
        case 'DISPATCHED':
          return 'warning';
        case 'RECEIVED':
          return 'success';
        case 'RETURNED':
          return 'info';
        case 'DAMAGED':
        case 'LOSS':
          return 'error';
        default:
          return 'default';
      }
    });
  }

  void _registerRoleFunctions() {
    // True when an identifier is a real Beneficiary ID taken from the pool,
    // false when it is the DEFAULT placeholder (a generated uuid).
    //
    // The configs already branch on this in four places - the member card
    // shows the id when true and a "NO_BENEFICIARY_ID" tag when false - but
    // the function was never registered. FunctionRegistry.call returns null
    // for an unknown name, which renders as '', so BOTH `==true` and `==false`
    // were false and neither branch ever showed. Closed households, which only
    // ever get a DEFAULT identifier, therefore fell through to displaying the
    // raw 36-char uuid.
    //
    // Usage: "visible": "{{fn:hasBeneficiaryId(item.individual.0.identifiers.0)}}==true"
    FunctionRegistry.register('hasBeneficiaryId', (args, stateData) {
      final identifier = args.isNotEmpty ? args.first : null;
      if (identifier == null) return false;

      // The arg resolves to the IdentifierModel as a map (or the model itself
      // when it comes straight off an entity), so read the type off either.
      String? identifierType;
      if (identifier is Map) {
        identifierType = identifier['identifierType']?.toString();
      } else {
        try {
          identifierType = (identifier as dynamic).identifierType?.toString();
        } catch (_) {
          return false;
        }
      }

      return identifierType?.trim().toUpperCase() == 'UNIQUE_BENEFICIARY_ID';
    });

    // Returns the UNIQUE_BENEFICIARY_ID's identifierId from a list of
    // identifiers, or '' when the individual has none (e.g. a closed or
    // consent-declined household, which only ever carries a DEFAULT
    // identifier - a raw 36-char uuid).
    //
    // Callers previously read "identifiers.0.identifierId", i.e. picked by
    // POSITION. Ordering is not guaranteed: buildIdentifierEntries appends the
    // Identification Type/Number pair after the idPopulator entry, and the
    // pool-assignment path inserts the token at index 0 only on the create
    // path - so on other paths index 0 is the DEFAULT identifier and that
    // uuid was carried into the delivery TaskModel as the beneficiary id.
    // Selecting by type removes the dependence on ordering entirely.
    //
    // Usage: "value": "{{fn:getBeneficiaryId(item.individual.0.identifiers)}}"
    FunctionRegistry.register('getBeneficiaryId', (args, stateData) {
      final identifiers = args.isNotEmpty ? args.first : null;
      if (identifiers == null) return '';

      String? readField(dynamic identifier, String key) {
        if (identifier is Map) return identifier[key]?.toString();
        try {
          return ((identifier as dynamic).toMap() as Map)[key]?.toString();
        } catch (_) {}
        try {
          switch (key) {
            case 'identifierType':
              return (identifier as dynamic).identifierType?.toString();
            case 'identifierId':
              return (identifier as dynamic).identifierId?.toString();
          }
        } catch (_) {}
        return null;
      }

      // Accept either the list or a single identifier.
      final list = identifiers is List ? identifiers : [identifiers];

      String? fallback;
      for (final identifier in list) {
        if (identifier == null) continue;
        final id = readField(identifier, 'identifierId');
        if (id == null || id.trim().isEmpty) continue;
        final type = readField(identifier, 'identifierType');
        if (type?.trim().toUpperCase() == 'UNIQUE_BENEFICIARY_ID') {
          return id.trim();
        }
        fallback ??= id.trim();
      }

      // No token: fall back to whatever identifier the individual does have
      // (in practice the DEFAULT one). A device that has not downloaded any
      // Beneficiary IDs registers households with only a DEFAULT identifier -
      // the pool-assignment block in transformer_executor is skipped when the
      // pool is empty, so that DEFAULT is genuinely all there is, and it must
      // still travel to the delivery task as the beneficiary reference.
      // Returning '' here would silently drop the only id those households
      // have. This does NOT reintroduce the bug it was written for: that was
      // a DEFAULT uuid winning over an existing token purely because it sat
      // at index 0, and the type check above now always wins that case.
      return fallback ?? '';
    });

    // True when the logged-in user holds any of the given role codes.
    // Codes are matched case-insensitively against RolesType values.
    // Usage: "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true"
    FunctionRegistry.register('hasRole', (args, stateData) {
      final requestedRoles = args
          .expand((arg) => arg is List ? arg : [arg])
          .where((arg) => arg != null)
          .map((arg) => arg.toString().trim().toUpperCase())
          .where((code) => code.isNotEmpty)
          .toSet();
      if (requestedRoles.isEmpty) return false;

      try {
        return context.loggedInUserRoles
            .any((role) => requestedRoles.contains(role.code.toUpperCase()));
      } catch (_) {
        return false;
      }
    });

    // True when the downloaded beneficiary ID pool (uniqueIdPoolCount, kept
    // live by LOAD_UNIQUE_ID_POOL) meets or exceeds the configured minimum
    // (singleton.beneficiaryIdMinCount). Gates the Registrar's "Register New
    // Beneficiary" button so a household can't be started without enough
    // beneficiary IDs downloaded to assign one.
    // Usage: "{{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}"
    FunctionRegistry.register('hasMinimumBeneficiaryId', (args, stateData) {
      if (args.length < 2) return false;
      final minCount = num.tryParse(args[0]?.toString() ?? '');
      final actualCount = num.tryParse(args[1]?.toString() ?? '');
      if (minCount == null || actualCount == null) return false;
      return actualCount >= minCount;
    });
  }

  void _registerFacilityFunctions() {
    FunctionRegistry.register('getUserFacilityId', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .where((role) => role.code == RolesType.distributor.toValue())
          .toList()
          .isNotEmpty;
      final isWareHouseMgr = context.loggedInUserRoles
          .where((role) => role.code == RolesType.warehouseManager.toValue())
          .toList()
          .isNotEmpty;
      if (isDistributor && !isWareHouseMgr) {
        return context.loggedInUserUuid;
      }
      try {
        List<Map<String, dynamic>>? projectFacilities;
        projectFacilities = stateData.modelMap['ProjectFacilityModel'];
        if (projectFacilities == null || projectFacilities.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pfModels = base.results['projectFacility'];
            if (pfModels != null && pfModels.isNotEmpty) {
              projectFacilities = pfModels
                  .whereType<ProjectFacilityModel>()
                  .map((pf) => <String, dynamic>{
                        'facilityId': pf.facilityId,
                      })
                  .toList();
            }
          }
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          return '';
        }
        for (var facility in projectFacilities) {
          final facilityId = facility['facilityId']?.toString() ?? '';
          if (facilityId.isNotEmpty) {
            return facilityId;
          }
        }
        return '';
      } catch (e) {
        debugPrint('getUserFacilityId error: $e');
        return '';
      }
    });

    FunctionRegistry.register('getProjectFacilities', (args, stateData) {
      try {
        List<Map<String, dynamic>>? projectFacilities;
        if (stateData.modelMap != null) {
          projectFacilities = stateData.modelMap['ProjectFacilityModel'];
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pfModels = base.results['projectFacility'];
            if (pfModels != null && pfModels.isNotEmpty) {
              projectFacilities = pfModels
                  .whereType<ProjectFacilityModel>()
                  .where((pf) {
                    final facilityLevel = pf.additionalFields?.fields
                        .where((f) => f.key == 'facilityLevel')
                        .firstOrNull
                        ?.value;
                    return facilityLevel == null || facilityLevel == 'current';
                  })
                  .map((pf) => <String, dynamic>{
                        'facilityId': pf.facilityId,
                      })
                  .toList();
            }
          }
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          return <Map<String, dynamic>>[];
        }
        final filtered = projectFacilities.where((pf) {
          final additionalFields =
              pf['additionalFields'] as Map<String, dynamic>?;
          if (additionalFields == null) return true;
          final fields = additionalFields['fields'] as List?;
          if (fields == null) return true;
          for (final field in fields) {
            if (field is Map &&
                field['key'] == 'facilityLevel' &&
                field['value'] != null) {
              return field['value'] == 'current';
            }
          }
          return true;
        }).toList();
        return filtered
            .map((pf) => {
                  'code': pf['facilityId']?.toString() ?? '',
                  'name': 'FAC_${pf['facilityId']?.toString() ?? ''}',
                })
            .where((item) => item['code']!.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('getProjectFacilities error: $e');
        return <Map<String, dynamic>>[];
      }
    });

    FunctionRegistry.register('getProjectProductVariantIds', (args, stateData) {
      try {
        List<Map<String, dynamic>>? productVariants;
        productVariants = stateData.modelMap['ProductVariantModel'];
        if (productVariants == null || productVariants.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pvModels = base.results['productVariant'];
            if (pvModels != null && pvModels.isNotEmpty) {
              productVariants = pvModels
                  .whereType<ProductVariantModel>()
                  .map((pv) => <String, dynamic>{'id': pv.id})
                  .toList();
            }
          }
        }
        if (productVariants == null || productVariants.isEmpty) {
          return '';
        }
        return productVariants
            .map((pv) => pv['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .join(',');
      } catch (e) {
        debugPrint('getProjectProductVariantIds error: $e');
        return '';
      }
    });

    FunctionRegistry.register('getCurrentFacilities', (args, stateData) {
      try {
        List<dynamic>? projectFacilities;

        if (args.isNotEmpty && args.first != null) {
          projectFacilities = args.first as List<dynamic>?;
        }

        if (projectFacilities == null || projectFacilities.isEmpty) {
          return <Map<String, dynamic>>[];
        }

        final currentFacilities = projectFacilities.where((pf) {
          if (pf is! Map) return false;
          final additionalFields =
              pf['additionalFields'] as Map<String, dynamic>?;
          if (additionalFields == null) return true;
          final fields = additionalFields['fields'] as List?;
          if (fields == null) return true;
          for (final field in fields) {
            if (field is Map && field['key'] == 'facilityLevel') {
              final value = field['value'];
              return value == null || value == 'current';
            }
          }
          return true;
        }).toList();

        return currentFacilities;
      } catch (e) {
        debugPrint('getCurrentFacilities error: $e');
        return <Map<String, dynamic>>[];
      }
    });

    FunctionRegistry.register('getFacilityName', (args, stateData) {
      if (args.isEmpty) return '';
      final facilityId = args.first?.toString() ?? '';
      if (facilityId.isEmpty) return '';
      return facilityId.contains('F') ? 'FAC_$facilityId' : facilityId;
    });

    FunctionRegistry.register('hasResults', (args, stateData) {
      if (args.isEmpty) return false;
      final modelKey = args.first?.toString() ?? '';
      if (modelKey.isEmpty) return false;
      final results = stateData.modelMap[modelKey];
      return results != null && results.isNotEmpty;
    });
  }

  void _registerStockFunctions() {
    // Returns true when at least one product has a balance > 0.
    // Fail-open: returns true when the cache has no facility set yet.
    FunctionRegistry.register('hasStockForRegistration', (args, stateData) {
      final cache = StockBalanceCache.instance;
      if (cache.facilityId.isEmpty) return true;
      if (cache.cache.isEmpty) return false;
      final s = cache.cache.values.any((balance) => balance > 0);
      print(s);
      print(cache.cache.values.any((balance) => balance > 0));
      return cache.cache.values.any((balance) => balance > 0);
    });

    FunctionRegistry.register("isClosedHousehold", (args, stateData) {
      if (args.isEmpty || args.first == null) return false;
      dynamic taskData = args.first;
      if (taskData is Map && taskData['TaskModel'] != null) {
        taskData = taskData['TaskModel'];
      }
      final tasks = taskData is List ? taskData : [taskData];

      String? getStatus(dynamic task) {
        if (task is Map) return task['status']?.toString().toUpperCase();
        try {
          return (task as dynamic).status?.toString().toUpperCase();
        } catch (_) {
          try {
            final mapped = (task as dynamic).toMap();
            return mapped is Map
                ? mapped['status']?.toString().toUpperCase()
                : null;
          } catch (_) {
            return null;
          }
        }
      }

      // Check if ANY task has ADMINISTRATION_SUCCESS or VISITED status (not just the last one)
      for (final task in tasks) {
        final status = getStatus(task);
        if (status == 'ADMINISTRATION_SUCCESS' || status == 'VISITED')
          return true;
      }

      return false;
    });

    // Distinguishes a household marked closed (via Mark Closed Household or
    // a declined consent) from a normal not-yet-delivered one, so search can
    // show "Closed Household" instead of "Delivery Pending" for it. Once the
    // household is reopened and its details are filled in, its task status
    // moves off CLOSED_HOUSEHOLD (see the HOUSEHOLD flow's isEdit &&
    // isClosedHousehold branch in REGISTRATION.json), so this naturally
    // stops matching and it falls back to the normal pending display.
    FunctionRegistry.register("isHouseholdMarkedClosed", (args, stateData) {
      dynamic readField(dynamic value, String key) {
        if (value is Map) return value[key];
        try {
          final mapped = (value as dynamic)?.toMap();
          if (mapped is Map && mapped.containsKey(key)) return mapped[key];
        } catch (_) {
          // Fall back to the generated JSON representation below.
        }
        try {
          final mapped = (value as dynamic)?.toJson();
          if (mapped is Map) return mapped[key];
        } catch (_) {
          // Some entity wrappers expose properties without a mapper.
        }
        return null;
      }

      bool isConsentDeclined(dynamic household) {
        var additionalFields = readField(household, 'additionalFields');
        if (additionalFields is String) {
          try {
            additionalFields = jsonDecode(additionalFields);
          } catch (_) {
            return false;
          }
        }
        if (additionalFields is! Map) return false;

        dynamic consent = additionalFields['caregiverConsent'];
        final fields = additionalFields['fields'];
        if (fields is List) {
          for (final field in fields) {
            if (readField(field, 'key') == 'caregiverConsent') {
              consent = readField(field, 'value');
              break;
            }
          }
        }
        return consent?.toString().toUpperCase() == 'FALSE';
      }

      // A declined-consent household must return to the consent page even if
      // its task relation is missing from this search result.
      if (args.length > 1 && args[1] != null) {
        if (isConsentDeclined(args[1])) return true;
      }

      if (args.isEmpty || args.first == null) {
        return false;
      }

      dynamic taskData = args.first;
      if (taskData is Map && taskData['TaskModel'] != null) {
        taskData = taskData['TaskModel'];
      }
      final tasks = taskData is List
          ? taskData
          : (readField(taskData, 'status') != null ? [taskData] : <dynamic>[]);
      if (tasks.isEmpty) return false;
      dynamic latestTask;
      int? latestCreatedTime;
      for (final task in tasks) {
        final clientAudit = readField(task, 'clientAuditDetails');
        final audit = readField(task, 'auditDetails');
        final createdTime = readField(clientAudit, 'createdTime') ??
            readField(audit, 'createdTime') ??
            readField(task, 'createdDate');
        final parsedTime = createdTime is num
            ? createdTime.toInt()
            : int.tryParse(createdTime?.toString() ?? '');
        if (parsedTime != null &&
            (latestCreatedTime == null || parsedTime >= latestCreatedTime)) {
          latestTask = task;
          latestCreatedTime = parsedTime;
        }
      }

      // Keep the legacy ordering fallback only when this data has no usable
      // timestamps. Search results are otherwise not guaranteed to be ordered.
      latestTask ??= tasks.last;
      final status = readField(latestTask, 'status');
      return status?.toString().toUpperCase() == 'CLOSED_HOUSEHOLD';
    });

    FunctionRegistry.register("isCaregiverConsentMissing", (args, stateData) {
      if (args.isEmpty || args.first == null) return true;
      final household = args.first;
      dynamic additionalFields;
      if (household is Map) {
        additionalFields = household['additionalFields'];
      } else {
        try {
          additionalFields = (household as dynamic).additionalFields;
        } catch (_) {
          return true;
        }
      }
      if (additionalFields is String) {
        try {
          additionalFields = jsonDecode(additionalFields);
        } catch (_) {
          return true;
        }
      }
      if (additionalFields is! Map) return true;
      final fields = additionalFields['fields'];
      dynamic consent;
      if (fields is List) {
        for (final field in fields) {
          final key = field is Map ? field['key'] : (field as dynamic).key;
          if (key == 'caregiverConsent') {
            consent = field is Map ? field['value'] : (field as dynamic).value;
            break;
          }
        }
      } else {
        consent = additionalFields['caregiverConsent'];
      }
      return consent == null || consent.toString().isEmpty;
    });

    // Returns a formatted message listing each product's available balance.
    FunctionRegistry.register('getRegistrationInsufficientStockMessage',
        (args, stateData) {
      final localization = FlowBuilderLocalization.of(context);
      final message =
          localization.translate('INSUFFICIENT_STOCK_DISTRIBUTION_MESSAGE');
      final balanceLabel = localization.translate('ITN_BALANCE_LABEL');
      final requiredLabel = localization.translate('REQUIRED_LABEL');

      final result = StockBalanceCache.instance.stockCheckResult;
      if (result is Map) {
        final products = result['products'] as List?;

        if (products != null && products.isNotEmpty) {
          final p = products.first as Map<String, dynamic>;
          final available = (p['available'] as num?)?.toDouble() ?? 0.0;
          final displayAvailable = available < 0 ? 0.0 : available;
          final required = (p['required'] as num?)?.toDouble() ?? 0.0;
          return '$message\n$balanceLabel = ${displayAvailable.toStringAsFixed(0)}\n$requiredLabel = ${required.toStringAsFixed(0)}';
        }
      }
      // Fallback: use total balance from cache
      final totalBalance = StockBalanceCache.instance.cache.values
          .fold<double>(0, (sum, v) => sum + (v < 0 ? 0.0 : v));
      return '$message\n$balanceLabel = ${totalBalance.toStringAsFixed(0)}';
    });

    FunctionRegistry.register('hasStockForDelivery', (args, stateData) {
      if (args.isEmpty) return true;
      final eligibleProducts = args.first;
      if (eligibleProducts == null) return true;
      List<dynamic> productList = [];
      if (eligibleProducts is List) {
        productList = eligibleProducts;
      } else if (eligibleProducts is Map) {
        productList = [eligibleProducts];
      }
      if (productList.isEmpty) return true;
      final cache = StockBalanceCache.instance;
      if (cache.facilityId.isEmpty) return true;
      final List<Map<String, dynamic>> insufficientProducts = [];
      for (final product in productList) {
        if (product is! Map) continue;
        final productVariantsList = product['ProductVariants'];
        if (productVariantsList is! List) continue;
        for (final variant in productVariantsList) {
          if (variant is! Map) continue;
          final productId = variant['productVariantId']?.toString();
          final productName =
              variant['name']?.toString() ?? productId ?? 'Unknown';
          if (productId == null || productId.isEmpty) continue;
          final rawQuantity =
              double.tryParse(variant['quantity']?.toString() ?? '1') ?? 1.0;
          // Cap to the same per-household maximum ResourceCard enforces on
          // the quantity actually entered, so this check (and the "required"
          // figure shown in the insufficient-stock message) never demands
          // more stock than a delivery could ever actually use.
          final quantity = rawQuantity > maxDeliveryQuantityPerHousehold
              ? maxDeliveryQuantityPerHousehold.toDouble()
              : rawQuantity;
          final key = productId;
          final balance = cache.cache[key] ?? 0.0;
          if (balance < quantity) {
            insufficientProducts.add({
              'name': productName,
              'required': quantity,
              'available': balance,
            });
          }
        }
      }
      if (insufficientProducts.isEmpty) {
        cache.setStockCheckResult(null);
        return true;
      }
      cache.setStockCheckResult({
        'key': 'INSUFFICIENT_STOCK',
        'products': insufficientProducts,
      });
      return false;
    });

    FunctionRegistry.register('hasStockForRedose', (args, stateData) {
      if (args.isEmpty || args.first == null) return true;
      final cache = StockBalanceCache.instance;
      if (cache.facilityId.isEmpty) return true;

      // Normalise task list
      List<Map<String, dynamic>> tasks = [];
      if (args.first is List) {
        for (final item in args.first as List) {
          if (item is Map<String, dynamic>) {
            tasks.add(item);
          } else if (item is Map) {
            tasks.add(Map<String, dynamic>.from(item));
          } else {
            try {
              tasks.add((item as dynamic).toMap() as Map<String, dynamic>);
            } catch (_) {
              try {
                tasks.add((item as dynamic).toJson() as Map<String, dynamic>);
              } catch (_) {}
            }
          }
        }
      }

      // Find the last ADMINISTRATION_SUCCESS or DELIVERED task
      Map<String, dynamic>? lastDeliveryTask;
      for (int i = tasks.length - 1; i >= 0; i--) {
        final status = tasks[i]['status']?.toString().toUpperCase() ?? '';
        if (status == 'ADMINISTRATION_SUCCESS') {
          lastDeliveryTask = tasks[i];
          break;
        }
      }

      if (lastDeliveryTask == null) return true;

      final List resources = lastDeliveryTask['resources'];
      if (resources.isEmpty) return true;

      final List<Map<String, dynamic>> insufficientProducts = [];
      for (final resource in resources) {
        final productId = resource['productVariantId']?.toString();
        if (productId == null || productId.isEmpty) continue;

        final rawQuantity =
            double.tryParse(resource['quantity']?.toString() ?? '1') ?? 1.0;
        // A redose must never ask for more than the per-household cap
        // either, even for a historical task recorded before this cap
        // existed.
        final quantity = rawQuantity > maxDeliveryQuantityPerHousehold
            ? maxDeliveryQuantityPerHousehold.toDouble()
            : rawQuantity;
        final balance = cache.cache[productId] ?? 0.0;
        if (balance < quantity) {
          insufficientProducts.add({
            'name': productId,
            'required': quantity,
            'available': balance,
          });
        }
      }

      if (insufficientProducts.isEmpty) {
        cache.setStockCheckResult(null);
        return true;
      }
      cache.setStockCheckResult({
        'key': 'INSUFFICIENT_STOCK',
        'products': insufficientProducts,
      });
      return false;
    });

    FunctionRegistry.register('getInsufficientStockMessage', (args, stateData) {
      final result = StockBalanceCache.instance.stockCheckResult;
      if (result is Map) {
        final key = result['key'] as String?;
        final products = result['products'] as List?;
        if (key == 'INSUFFICIENT_STOCK' && products != null) {
          String message = '';
          for (int i = 0; i < products.length; i++) {
            final p = products[i] as Map<String, dynamic>;
            final name = p['name'] ?? 'Unknown';
            final required = p['required'] ?? 0;
            final available = p['available'] ?? 0;
            message += '\n$name: $required REQUIRED, $available AVAILABLE';
          }
          return '$key::$message';
        }
      }
      return 'INSUFFICIENT_STOCK';
    });
  }

  void _registerViewTransactionFunctions() {
    String getStockEntryTypeFromFields(dynamic fields) {
      if (fields == null) return '';
      if (fields is List) {
        for (var field in fields) {
          if (field is Map && field['key']?.toString() == 'stockEntryType') {
            return field['value']?.toString().toUpperCase() ?? '';
          }
          try {
            final dynamic typedField = field;
            if (typedField.key?.toString() == 'stockEntryType') {
              return typedField.value?.toString().toUpperCase() ?? '';
            }
          } catch (_) {
            // Ignore fields that do not expose the additional-field shape.
          }
        }
      }
      return '';
    }

    FunctionRegistry.register('getStockEntryTypeFromFields', (args, stateData) {
      if (args.isEmpty) return '';
      return getStockEntryTypeFromFields(args.first);
    });

    // Reads a single value from the additionalFields key/value list.
    String getFieldValue(dynamic fields, String key) {
      if (fields is List) {
        for (var field in fields) {
          if (field is Map && field['key'] == key) {
            return field['value']?.toString() ?? '';
          }
        }
      }
      return '';
    }

    // Prefixes a facility id with FAC_ (skips empty ids so we never show a bare
    // "FAC_"). Used to display facility parties on the transaction screens.
    String withFacilityPrefix(dynamic id) {
      final value = id?.toString() ?? '';
      return value.isEmpty ? '' : 'FAC_$value';
    }

    // Resolves the delivery-team (CDD) userName for display. Prefers the
    // captured deliveryTeamName (set when the team is the RECEIVER, e.g. an
    // issue). When the team is the SENDER (e.g. a return) the name was not
    // captured into deliveryTeamName, but the raw scanned QR is persisted in
    // the deliveryTeam field as "userName||userUuid" -> extract the name from
    // there. Returns '' when no name is available (caller falls back to the id).
    String resolveTeamName(dynamic fields) {
      final captured = getFieldValue(fields, 'deliveryTeamName');
      if (captured.isNotEmpty) return captured;
      final scanned = getFieldValue(fields, 'deliveryTeam');
      if (scanned.contains('||')) return scanned.split('||').first.trim();
      return '';
    }

    FunctionRegistry.register('getFirstPagePartyLabel', (args, stateData) {
      if (args.isEmpty) return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      final stockEntryType = getStockEntryTypeFromFields(args.first);
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return 'INVENTORY_SENDER_LABEL';
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return 'INVENTORY_RECEIVER_LABEL';
        default:
          return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      }
    });

    FunctionRegistry.register('getFirstPageParty', (args, stateData) {
      if (args.length < 3) return '';
      final stockEntryType = getStockEntryTypeFromFields(args[0]);
      final senderType = args.length > 3 ? (args[3]?.toString() ?? '') : '';
      final receiverType = args.length > 4 ? (args[4]?.toString() ?? '') : '';
      final teamName = resolveTeamName(args[0]);
      // A STAFF party (CDD / delivery team member) is an individual, not a
      // facility -> show the captured userName (deliveryTeamName), no FAC_
      // prefix; fall back to the raw id (userUUID) only when no name was
      // captured. Facility (non-STAFF) parties get the FAC_ prefix.
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          if (senderType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[1]?.toString() ?? '');
          }
          return withFacilityPrefix(args[1]);
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          if (receiverType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[2]?.toString() ?? '');
          }
          return withFacilityPrefix(args[2]);
        default:
          if (senderType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[1]?.toString() ?? '');
          }
          return withFacilityPrefix(args[1]);
      }
    });

    FunctionRegistry.register('getSecondPagePartyLabel', (args, stateData) {
      if (args.isEmpty) return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      final stockEntryType = getStockEntryTypeFromFields(args.first);
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return 'INVENTORY_RECEIVER_LABEL';
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return 'INVENTORY_SENDER_LABEL';
        default:
          return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      }
    });

    FunctionRegistry.register('getSecondPageParty', (args, stateData) {
      if (args.length < 3) return '';
      final stockEntryType = getStockEntryTypeFromFields(args[0]);
      final senderType = args.length > 3 ? (args[3]?.toString() ?? '') : '';
      final receiverType = args.length > 4 ? (args[4]?.toString() ?? '') : '';
      final teamName = resolveTeamName(args[0]);
      // STAFF party -> show captured userName (no FAC_ prefix); fall back to the
      // raw id. Facility parties get the FAC_ prefix so the details page matches
      // the transaction list (getFirstPageParty).
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          if (receiverType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[2]?.toString() ?? '');
          }
          return withFacilityPrefix(args[2]);
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          if (senderType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[1]?.toString() ?? '');
          }
          return withFacilityPrefix(args[1]);
        default:
          if (receiverType == 'STAFF') {
            return teamName.isNotEmpty ? teamName : (args[2]?.toString() ?? '');
          }
          return withFacilityPrefix(args[2]);
      }
    });
  }
}

class StockBalanceCache {
  StockBalanceCache._();
  static final StockBalanceCache _instance = StockBalanceCache._();
  static StockBalanceCache get instance => _instance;

  String _facilityId = '';
  final Map<String, double> _cache = {};
  dynamic _stockCheckResult;

  String get facilityId => _facilityId;
  Map<String, double> get cache => _cache;
  dynamic get stockCheckResult => _stockCheckResult;

  void setCache(String facilityId, Map<String, double> cache) {
    _facilityId = facilityId;
    _cache.clear();
    _cache.addAll(cache);
    _stockCheckResult = null;
  }

  void setStockCheckResult(dynamic result) {
    _stockCheckResult = result;
  }

  void clear() {
    _facilityId = '';
    _cache.clear();
    _stockCheckResult = null;
  }
}

@Deprecated('Use StockBalanceCache.instance.setCache instead')
void setStockBalanceCache(String facilityId, Map<String, double> cache) {
  StockBalanceCache.instance.setCache(facilityId, cache);
}
