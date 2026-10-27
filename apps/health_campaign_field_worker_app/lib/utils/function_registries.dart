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
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_initialization/app_initialization.dart';
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
    _registerProjectFacilityFunctions();
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

    // Shortfall Return (Accept/Partial Accept PRD): dispatched minus actual
    // received, used both to size the auto-created return transaction and to
    // display the shortfall on view-transaction-details.
    FunctionRegistry.register('subtractQuantity', (args, stateData) {
      if (args.length < 2) return '';

      num? toNum(dynamic raw) =>
          raw is num ? raw : num.tryParse(raw?.toString().trim() ?? '');

      final a = toNum(args[0]);
      final b = toNum(args[1]);
      if (a == null || b == null) return '';

      final difference = a - b;
      return difference == difference.roundToDouble()
          ? difference.toInt()
          : difference;
    });

    // viewTransactionDetails' main quantity row: a partially-accepted
    // StockModel has its own `quantity` field overwritten down to
    // actualQuantityReceived (see manage_stock.dart's onSecondaryAction),
    // with originalQuantityReceived preserving the true dispatched amount
    // separately - so the main row must prefer originalQuantityReceived
    // when present, falling back to the record's own quantity for a normal
    // (non-partial) transaction where originalQuantityReceived was never
    // set. Without this, the main row (labeled "Quantity Sent"/"Quantity
    // Received" per stockEntryType) duplicated the separate "Actual
    // Quantity Received" row below it instead of showing what was actually
    // dispatched.
    FunctionRegistry.register('coalesceQuantity', (args, stateData) {
      if (args.isEmpty) return '';
      for (final arg in args) {
        final text = arg?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return arg;
      }
      return '';
    });

    // The stock API may return a null top-level wayBillNumber even though the
    // submitted value is preserved in additionalFields. Prefer the API field
    // when populated and fall back to the saved additional field.
    FunctionRegistry.register('getWayBillNumber', (args, stateData) {
      for (final arg in args) {
        final value = arg?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return arg;
      }
      return '';
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

    /// Joins name parts with a single space, dropping the ones that are
    /// missing.
    ///
    /// Interpolating the parts directly ("{{...givenName}} {{...familyName}}")
    /// renders a missing part as the literal text "null" - a closed household
    /// captured with only a first name displayed as "Amara null" - and leaves
    /// a dangling space even when the template resolves to an empty string.
    /// Takes any number of parts so the same helper covers given/family and
    /// given/other/family orders.
    FunctionRegistry.register('fullName', (args, stateData) {
      final parts = <String>[];
      for (final arg in args) {
        if (arg == null) continue;
        final trimmed = arg.toString().trim();
        if (trimmed.isEmpty) continue;
        // A missing field can arrive as the string "null", and an unresolved
        // template can leak through as literal "{{...}}" text.
        if (trimmed.toLowerCase() == 'null') continue;
        if (trimmed.contains('{{') && trimmed.contains('}}')) continue;
        parts.add(trimmed);
      }
      return parts.join(' ');
    });

    FunctionRegistry.register('getCommentValue', (args, stateData) {
      for (final arg in args) {
        if (arg == null) continue;

        final value = arg.toString();
        final trimmed = value.trim();

        if (trimmed.isNotEmpty &&
            !(trimmed.contains('{{') && trimmed.contains('}}')) &&
            trimmed.toLowerCase() != 'null') {
          return value;
        }
      }

      return null;
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
      final stockEntryType = args.first?.toString().toUpperCase() ?? '';
      const labels = {
        'RECEIPT': 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL',
        'RETURNED': 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL',
        'ISSUED': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'DISPATCH': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'LESS': 'APPONE_INVENTORY_QUANTITY_LOST_LABEL',
        'EXCESS': 'APPONE_INVENTORY_QUANTITY_LABEL',
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
      final stockEntryType = args.first?.toString().toUpperCase() ?? '';
      final transactionReason =
          args.length > 1 ? args[1]?.toString().toUpperCase() ?? '' : '';
      final discrepancyReason =
          args.length > 2 ? args[2]?.toString().toUpperCase() ?? '' : '';
      // Once an issued transaction has been accepted, show the receiver's
      // perspective in the UI. The stored entry type remains ISSUED for stock
      // balance/report calculations.
      //
      // This MUST be tested before the discrepancy-reason branches below. A
      // partially-accepted receipt now carries the discrepancy reason that
      // explains its shortfall (see the Partial Accept UPDATE_EVENT in
      // manage_stock.dart), and a STOCK_LOSS/STOCK_DAMAGE reason there would
      // otherwise retitle the receiver's own accepted receipt as "Stock Loss
      // Details"/"Stock Damaged Details". The record is still a receipt; the
      // reason only describes why less arrived than was sent.
      if (stockEntryType == 'ISSUED' && transactionReason == 'RECEIVED') {
        return 'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
      }
      // When an upper-level user resolves a shortfall, the acknowledged
      // record can retain stockEntryType=RETURNED while its discrepancy
      // reason classifies it as loss or damage. Match the view-transaction
      // heading to that classification, just as the report list does.
      if (discrepancyReason == 'STOCK_DAMAGE' ||
          transactionReason == 'STOCK_DAMAGE') {
        return 'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING';
      }
      if (discrepancyReason == 'STOCK_LOSS' ||
          transactionReason == 'STOCK_LOSS') {
        return 'INVENTORY_STOCK_LOSS_DETAILS_HEADING';
      }
      if (stockEntryType == 'RETURNED' || transactionReason == 'RETURNED') {
        return 'INVENTORY_STOCK_RETURN_DETAILS_HEADING';
      }
      const headings = {
        'ISSUED': 'INVENTORY_STOCK_ISSUE_DETAILS_HEADING',
        'RETURNED': 'INVENTORY_STOCK_RETURN_DETAILS_HEADING',
        'DAMAGED': 'INVENTORY_STOCK_DAMAGED_DETAILS_HEADING',
        'LOSS': 'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
        'LESS': 'INVENTORY_STOCK_LOSS_DETAILS_HEADING',
        'EXCESS': 'INVENTORY_STOCK_EXCESS_DETAILS_HEADING',
      };
      return headings[stockEntryType] ??
          'INVENTORY_STOCK_RECEIPT_DETAILS_HEADING';
    });

    // Optional 2nd arg: the record's stockEntryType.
    //
    // A LESS/EXCESS adjustment is stored with the transactionReason of the
    // movement that carried it - an excess is persisted as transactionType
    // RECEIVED with transactionReason RECEIVED - so echoing the raw reason
    // rendered "Received" on a record whose own heading said "Stock Excess
    // Details". The entry type is the meaningful reason for these two, so
    // use it when present and fall back to the stored reason otherwise.
    FunctionRegistry.register('getTransactionReasonDisplayCode',
        (args, stateData) {
      final stockEntryType = args.length > 1
          ? args[1]?.toString().trim().toUpperCase() ?? ''
          : '';
      const entryTypeLabels = {
        'EXCESS': 'INVENTORY_TRANSACTION_REASON_EXCESS',
        'LESS': 'INVENTORY_TRANSACTION_REASON_LESS',
      };
      final entryTypeLabel = entryTypeLabels[stockEntryType];
      if (entryTypeLabel != null) return entryTypeLabel;

      if (args.isEmpty || args.first == null) return null;
      final value = args.first.toString().trim();
      return value.isEmpty || value.toLowerCase() == 'null' ? null : value;
    });

    FunctionRegistry.register('getDiscrepancyReasonDisplayCode',
        (args, stateData) {
      if (args.isEmpty || args.first == null) return null;
      final reason = args.first.toString().trim().toUpperCase();
      if (reason.isEmpty || reason == 'NULL') return null;
      const labels = {
        'IN_TRANSIT': 'INVENTORY_DISCREPANCY_REASON_IN_TRANSIT',
        'STOCK_LOSS': 'INVENTORY_DISCREPANCY_REASON_STOCK_LOSS',
        'STOCK_DAMAGE': 'INVENTORY_DISCREPANCY_REASON_STOCK_DAMAGE',
        'OTHERS': 'INVENTORY_DISCREPANCY_REASON_OTHERS',
      };
      return labels[reason] ?? reason;
    });

    // Stock additionalFields.fields is a list of AdditionalField objects in
    // the app model and a list of key/value maps in API payloads. Incoming
    // transactions are grouped by MRN, so inspect every row in the group:
    // the original dispatch can be first and have no discrepancy reason,
    // while the linked shortfall row carries the reason.
    FunctionRegistry.register('getStockDiscrepancyReason', (args, stateData) {
      if (args.isEmpty || args.first == null) return '';
      final first = args.first;
      final stocks = first is List ? first : [first];
      for (final stock in stocks) {
        dynamic additionalFields;
        if (stock is Map) {
          additionalFields = stock['additionalFields'];
        } else {
          try {
            additionalFields = (stock as dynamic).additionalFields;
          } catch (_) {
            continue;
          }
        }

        if (additionalFields is String) {
          try {
            additionalFields = jsonDecode(additionalFields);
          } catch (_) {
            continue;
          }
        }

        dynamic fields;
        if (additionalFields is Map) {
          fields = additionalFields['fields'];
        } else {
          try {
            fields = (additionalFields as dynamic).fields;
          } catch (_) {
            continue;
          }
        }

        dynamic reason;
        if (fields is List) {
          for (final field in fields) {
            String? fieldKey;
            if (field is Map) {
              fieldKey = field['key']?.toString();
            } else {
              try {
                fieldKey = (field as dynamic).key?.toString();
              } catch (_) {
                continue;
              }
            }
            if (fieldKey != 'discrepancyReason') continue;
            if (field is Map) {
              reason = field['value'];
            } else {
              try {
                reason = (field as dynamic).value;
              } catch (_) {
                reason = null;
              }
            }
            break;
          }
        } else if (fields is Map) {
          reason = fields['discrepancyReason'];
        }

        final value = reason?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
      return '';
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
    FunctionRegistry.register('getReportStockQuantity', (args, stateData) {
      if (args.length < 2 || args[1] == null) return '';

      final reportType = args[0]?.toString() ?? '';
      // TableWidget rows can be EntityModels (as they are when read from the
      // wrapper modelMap) or maps (as they are in raw API/config data).
      // Accept both so this report helper behaves like item.quantity access.
      final rawStock = args[1];
      final Map stock;
      if (rawStock is Map) {
        stock = rawStock;
      } else if (rawStock is EntityModel) {
        stock = rawStock.toMap();
      } else {
        return '';
      }

      final rawAdditionalFields = stock['additionalFields'];
      final Map? additionalFields = rawAdditionalFields is Map
          ? rawAdditionalFields
          : rawAdditionalFields is EntityModel
              ? rawAdditionalFields.toMap()
              : null;
      final rawFields = additionalFields?['fields'];
      String? fieldValue(String key) {
        if (rawFields is List) {
          for (final field in rawFields) {
            final Map? fieldMap = field is Map
                ? field
                : field is EntityModel
                    ? field.toMap()
                    : null;
            if (fieldMap != null && fieldMap['key'] == key) {
              final value = fieldMap['value']?.toString();
              if (value != null && value.isNotEmpty && value != 'null') {
                return value;
              }
            }
          }
        } else if (rawFields is Map) {
          final value = rawFields[key]?.toString();
          if (value != null && value.isNotEmpty && value != 'null') {
            return value;
          }
        }
        return null;
      }

      // Partial acceptance edits quantity down to the received amount, while
      // the original sender's issue report must continue to show what they
      // dispatched. The accepted receiver's receipt report shows the actual
      // quantity received instead.
      final value = reportType == 'dispatch'
          ? fieldValue('originalQuantityReceived') ??
              stock['quantity']?.toString() ??
              ''
          : reportType == 'receipt'
              ? fieldValue('actualQuantityReceived') ??
                  stock['quantity']?.toString() ??
                  ''
              // Loss/Excess adjustments fall through to here. Fall back to
              // the additionalFields copy when the top-level column is null
              // - a record that has round-tripped through the server can
              // come back without it, which left the Quantity column blank
              // on the Loss and Excess reports even though the local record
              // plainly had a quantity.
              : stock['quantity']?.toString() ??
                  fieldValue('quantity') ??
                  '';
      // This helper is used for report display. Keep signed quantities in
      // storage for balance calculations, but show their magnitude in reports.
      final number = num.tryParse(value.toString().trim());
      if (number == null) return value;
      final absolute = number.abs();
      return absolute == absolute.roundToDouble() ? absolute.toInt() : absolute;
    });

    FunctionRegistry.register('getTransactionType', (args, stateData) {
      if (args.isEmpty) return [];
      final reportType = args.first?.toString() ?? '';
      const types = {
        'receipt': ['RECEIVED'],
        'dispatch': ['DISPATCHED'],
        'returned': ['DISPATCHED'],
        'damage': ['DISPATCHED'],
        'loss': ['DISPATCHED']
      };
      return types[reportType] ?? [];
    });

    FunctionRegistry.register('getTransactionReason', (args, stateData) {
      if (args.isEmpty) return [];
      final reportType = args.first?.toString() ?? '';
      const reasons = {
        'receipt': ['RECEIVED'],
        'dispatch': [],
        'returned': ['RETURNED'],
        'damage': ['DAMAGED_IN_STORAGE', 'DAMAGED_IN_TRANSIT'],
        'loss': ['LOST_IN_STORAGE', 'LOST_IN_TRANSIT']
      };
      return reasons[reportType] ?? [];
    });

    FunctionRegistry.register('getStockEntryType', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      const entryTypes = {
        // "RECEIPT" is never actually persisted: the stockReceipt transformer
        // only builds that stockEntryType on a transient entity used to seed
        // the UPDATE_EVENT write (manage_stock.dart's stockReceiptDetails
        // onAction/onSecondaryAction) - the record that's actually saved is
        // the original dispatch, mutated in place, which keeps its original
        // "ISSUED" stockEntryType. Filtering for "RECEIPT" here always
        // matched zero rows, so the Stock Received report was permanently
        // empty. "ISSUED" + getSenderOrReceiver's receiverId (below) is what
        // the sender-side "Stock Issued" report (senderId) is NOT scoped to,
        // so this correctly isolates the receiving facility's accepted
        // dispatches instead.
        'receipt': 'ISSUED',
        'dispatch': 'ISSUED',
        'returned': 'RETURNED',
        'excess': 'EXCESS',
        'less': 'LESS',
      };
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      // Only accepted shortfall resolutions are stamped DAMAGED or LOSS.
      // Pending shortfall notifications remain RETURNED and must not appear
      // in these resolved discrepancy reports.
      // Historical accepted shortfall damage rows may still carry RETURNED;
      // the report applies separate reason and accepted-status filters so
      // pending returns cannot leak into the damage report.
      if (reportType == 'damage') return 'DAMAGED,RETURNED';
      if (reportType == 'loss') {
        // Distributor loss entries are recorded as LESS. Upper hierarchy
        // loss reports show lower-level STOCK_LOSS discrepancy records.
        return isDistributor ? 'LESS' : 'LOSS';
      }
      return entryTypes[reportType] ?? '';
    });

    FunctionRegistry.register('isResolvedDamageReport', (args, stateData) {
      return args.isNotEmpty && args.first?.toString() == 'damage';
    });

    // Distributor stock records use the user's UUID as sender/receiver id;
    // warehouse-manager records use a facility id selected in the report.
    FunctionRegistry.register('getReportFacilityId', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      if (isDistributor) return context.loggedInUserUuid ?? '';
      return args.length > 1 ? args[1]?.toString() ?? '' : '';
    });

    FunctionRegistry.register('getReportTransactionReasonFilter',
        (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      if (isDistributor &&
          (reportType == 'loss' || reportType == 'excess')) {
        // Adjustment explanations live in additionalFields.adjustmentReason.
        return '';
      }
      if (reportType == 'receipt') return 'RECEIVED';
      // These discrepancy reasons are written in additionalFields on the
      // accepted DAMAGED/LOSS record, not the top-level transactionReason.
      if (reportType == 'damage') {
        return 'STOCK_DAMAGE,DAMAGED_IN_STORAGE,DAMAGED_IN_TRANSIT';
      }
      if (reportType == 'loss') {
        return 'STOCK_LOSS,LOST_IN_STORAGE,LOST_IN_TRANSIT';
      }
      if (reportType == 'returned') return 'RETURNED';
      return '';
    });

    FunctionRegistry.register('getSenderOrReceiver', (args, stateData) {
      if (args.isEmpty) return 'receiverId';
      final reportType = args.first?.toString() ?? '';
      const senderTypes = {
        'dispatch',
        'returned',
        'excess',
        'less',
      };
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      // Distributor loss is recorded by the user as sender. Excess is an
      // incoming adjustment from the higher-level warehouse, so the user is
      // the receiver. Filter the party direction used by each persisted flow.
      if (isDistributor && (reportType == 'loss' || reportType == 'excess')) {
        return reportType == 'excess' ? 'receiverId' : 'senderId';
      }
      // Lower-facility damage/loss shortfall records are addressed to the
      // upper facility that issued the stock. Its report must filter on the
      // receiver, which is the selected upper facility.
      if (reportType == 'damage' || reportType == 'loss') return 'receiverId';
      return senderTypes.contains(reportType) ? 'senderId' : 'receiverId';
    });

    FunctionRegistry.register('getReportTransactionReasonFilterKey',
        (args, stateData) {
      final reportType = args.isEmpty ? '' : args.first?.toString() ?? '';
      // Discrepancy reasons are stored in additionalFields, not the
      // top-level transactionReason column.
      if (reportType == 'damage' || reportType == 'loss') {
        return 'additionalFields';
      }
      return 'transactionReason';
    });

    FunctionRegistry.register('getAuditFilterKey', (args, stateData) {
      if (args.isEmpty) return 'clientCreatedBy';
      final reportType = args.first?.toString() ?? '';
      return reportType == 'receipt' ? 'clientModifiedBy' : 'clientCreatedBy';
    });

    FunctionRegistry.register('getSecondaryType', (args, stateData) {
      if (args.isEmpty) return 'WAREHOUSE';
      final facilityFromWhich = args.first?.toString() ?? '';
      return facilityFromWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
    });

    // Resolves the parties for a distributor's less/excess adjustment.
    // Loss is an outgoing adjustment from the distributor; excess represents
    // additional stock received from the selected higher-level warehouse.
    // Args: [recordType, partyField, facilityFromWhich, facilityToWhich].
    FunctionRegistry.register('getStockLessExcessPartyValue', (args, stateData) {
      String argAt(int index) =>
          args.length > index ? (args[index]?.toString() ?? '') : '';

      final recordType = argAt(0).toUpperCase();
      final partyField = argAt(1);
      final facilityFromWhich = argAt(2);
      final facilityToWhich = argAt(3);
      final isExcess = recordType == 'EXCESS';
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());

      switch (partyField) {
        case 'senderId':
          if (isExcess) return facilityToWhich;
          if (isDistributor) return context.loggedInUserUuid ?? '';
          return facilityFromWhich == 'DELIVERY_TEAM'
              ? (context.loggedInUserUuid ?? '')
              : facilityFromWhich;
        case 'senderType':
          if (isExcess) return 'WAREHOUSE';
          if (isDistributor) return 'STAFF';
          return facilityFromWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
        case 'receiverId':
          return isExcess
              ? (context.loggedInUserUuid ?? '')
              : facilityToWhich;
        case 'receiverType':
          return isExcess ? 'STAFF' : 'WAREHOUSE';
        default:
          return '';
      }
    });

    FunctionRegistry.register('getTeamCode', (args, stateData) {
      if (args.isEmpty) return '';
      final teamCode = args.first?.toString() ?? '';
      if (teamCode.contains("||")) {
        return teamCode.split("||").last.trim();
      }
      return teamCode;
    });

    // Returns the code of the first delivery comment option from app config.
    // Used to auto-select the first product detail option in stock details.
    FunctionRegistry.register('getFirstDeliveryCommentCode', (args, stateData) {
      try {
        final appConfigState = context.read<AppInitializationBloc>().state;
        if (appConfigState is! AppInitialized) return '';
        final deliveryCommentOptions =
            appConfigState.appConfiguration.deliveryCommentOptions;
        if (deliveryCommentOptions == null || deliveryCommentOptions.isEmpty)
          return '';
        return deliveryCommentOptions.first.code;
      } catch (_) {
        return '';
      }
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
    // The destination team (warehouseDetails.teamCode) is the one receiverId
    // needs. stockDetails.deliveryTeam is the team on the *sending* side
    // (returns / less-excess) and is only used as a fallback, so a flow that
    // populates just that field still resolves to a team rather than nothing.
    // stockEntryType and primaryRole are passed by the config but not needed:
    // which field is populated already identifies the side the team is on.
    //
    // args: [stockEntryType, primaryRole, warehouseDetails.teamCode,
    //        stockDetails.deliveryTeam]
    FunctionRegistry.register('getStockTeamCode', (args, stateData) {
      String argAt(int index) =>
          args.length > index ? (args[index]?.toString().trim() ?? '') : '';

      final destinationTeam = argAt(2);
      final rawTeam = destinationTeam.isNotEmpty ? destinationTeam : argAt(3);
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

    // Display the actual campaign beneficiary id even when the household has
    // other identifiers (for example the DEFAULT placeholder) before it.
    FunctionRegistry.register('getUniqueBeneficiaryId', (args, stateData) {
      final identifiers = args.isNotEmpty ? args.first : null;
      if (identifiers is! Iterable) return '';
      for (final identifier in identifiers) {
        if (identifier == null) continue;
        String? type;
        String? id;
        if (identifier is Map) {
          type = identifier['identifierType']?.toString();
          id = identifier['identifierId']?.toString();
        } else {
          try {
            type = (identifier as dynamic).identifierType?.toString();
            id = (identifier as dynamic).identifierId?.toString();
          } catch (_) {
            continue;
          }
        }
        if (type?.trim().toUpperCase() == 'UNIQUE_BENEFICIARY_ID' &&
            id != null &&
            id.isNotEmpty) {
          return id;
        }
      }
      return '';
    });

    // Household counts are stored in the Household model's additionalFields
    // list, while memberCount is a first-class field. Resolve a field by key
    // for the registration overview without relying on list ordering.
    FunctionRegistry.register('getAdditionalFieldValue', (args, stateData) {
      if (args.length < 2) return '';
      dynamic fields = args[0];
      final targetKey = args[1]?.toString();
      if (targetKey == null || targetKey.isEmpty) return '';
      if (fields is String) {
        try {
          fields = jsonDecode(fields);
        } catch (_) {
          return '';
        }
      }
      if (fields is Map) {
        final nestedFields = fields['fields'];
        if (nestedFields != null) fields = nestedFields;
      }
      if (fields is! Iterable) return '';
      for (final field in fields) {
        dynamic key;
        dynamic value;
        if (field is Map) {
          key = field['key'];
          value = field['value'];
        } else {
          try {
            key = (field as dynamic).key;
            value = (field as dynamic).value;
          } catch (_) {
            continue;
          }
        }
        if (key?.toString() == targetKey) return value?.toString() ?? '';
      }
      return '';
    });

    // Return the first captured identifier other than the generated
    // beneficiary id. The overview uses it for the identification type and
    // number rows, independent of identifier list ordering.
    FunctionRegistry.register('getCapturedIdentifierValue', (args, stateData) {
      if (args.length < 2 || args[0] is! Iterable) return null;
      final requestedKey = args[1]?.toString();
      for (final identifier in args[0] as Iterable) {
        dynamic type;
        dynamic value;
        if (identifier is Map) {
          type = identifier['identifierType'];
          value = identifier[requestedKey];
        } else {
          try {
            type = (identifier as dynamic).identifierType;
            value = requestedKey == 'identifierId'
                ? (identifier as dynamic).identifierId
                : (identifier as dynamic).identifierType;
          } catch (_) {
            continue;
          }
        }
        if (type?.toString().toUpperCase() != 'UNIQUE_BENEFICIARY_ID' &&
            type?.toString().toUpperCase() != 'DEFAULT' &&
            value != null &&
            value.toString().isNotEmpty) {
          return value;
        }
      }
      return null;
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
  }

  void _registerFacilityFunctions() {
    FunctionRegistry.register('getUserFacilityId', (args, stateData) {
      return _resolveUserFacilityId(stateData);
    });

    // Used by shortfallTransaction's senderType - a Distributor's
    // getUserFacilityId() deliberately returns their raw user UUID instead
    // of a facility ID (they have no ProjectFacilityModel row), so
    // shortfallTransaction can no longer hardcode senderType: WAREHOUSE for
    // every sender or the backend rejects the record (facility-lookup
    // validation fails on a UUID). Mirrors the exact isDistributor &&
    // !isWareHouseMgr check in _resolveUserFacilityId so the two always
    // agree on which users resolve to a UUID.
    FunctionRegistry.register('getUserPartyType', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue()) &&
          !context.loggedInUserRoles
              .any((role) => role.code == RolesType.warehouseManager.toValue());
      final isWareHouseMgr = context.loggedInUserRoles
          .any((role) => role.code == RolesType.warehouseManager.toValue());
      return (isDistributor && !isWareHouseMgr) ? 'STAFF' : 'WAREHOUSE';
    });

    // Same purpose as getUserPartyType, but for the OTHER party in a
    // shortfall/reissue exchange (carried forward as navigation.
    // senderFacilityId) - we don't have that party's role at hand, only
    // their already-resolved ID string, so detect a real facility by the
    // "F-" prefix convention used consistently across this platform;
    // anything else is a Distributor's raw user UUID.
    FunctionRegistry.register('getPartyTypeForFacilityId', (args, stateData) {
      if (args.isEmpty || args.first == null) return 'WAREHOUSE';
      final id = args.first.toString();
      return id.startsWith('F-') ? 'WAREHOUSE' : 'STAFF';
    });
  }

  // Extracted from getUserFacilityId so the hasStockFor* gates below can
  // resolve the current user's facility and compare it against
  // StockBalanceCache.instance.facilityId - without this, a gate called
  // right after a role switch (before stock_balance_card.dart's next
  // refresh) would trust a balance map left over from the PREVIOUS
  // logged-in user's facility.
  String _resolveUserFacilityId(dynamic stateData) {
    final isDistributor = context.loggedInUserRoles
        .where((role) => role.code == RolesType.distributor.toValue())
        .toList()
        .isNotEmpty;
    final isWareHouseMgr = context.loggedInUserRoles
        .where((role) => role.code == RolesType.warehouseManager.toValue())
        .toList()
        .isNotEmpty;
    if (isDistributor && !isWareHouseMgr) {
      return context.loggedInUserUuid ?? '';
    }
    try {
      List<Map<String, dynamic>>? projectFacilities;
      if (stateData?.modelMap != null) {
        projectFacilities = stateData!.modelMap['ProjectFacilityModel'];
      }
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
      // Must match stock_balance_executor.dart's _handleStockEntity
      // exactly: that executor picks its own facilityId from
      // currentFacilities.first (filtered to facilityLevel=='current' or
      // unset), not just the first ProjectFacilityModel in the list. A
      // user can have more than one ProjectFacilityModel (different
      // hierarchy levels) - without this same filter here, a
      // shortfallTransaction built with this facilityId as senderId could
      // end up DIFFERENT from the facilityId the balance executor later
      // resolves for the same user, so its own isSender check silently
      // fails to match the record it just created. That drops the
      // offsetting -quantity leg of the in-transit accept/reissue net-zero
      // entirely, leaving the +quantity credited with nothing to cancel it.
      final currentFacilities = projectFacilities.where((pf) {
        final additionalFields = pf['additionalFields'] as Map?;
        final fields = additionalFields?['fields'] as List?;
        if (fields == null) return true;
        for (final field in fields) {
          if (field is Map && field['key'] == 'facilityLevel') {
            final value = field['value'];
            return value == null || value == 'current';
          }
        }
        return true;
      }).toList();
      final facilitiesToSearch =
          currentFacilities.isNotEmpty ? currentFacilities : projectFacilities;
      for (var facility in facilitiesToSearch) {
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
  }

  void _registerProjectFacilityFunctions() {
    FunctionRegistry.register('getProjectFacilities', (args, stateData) {
      try {
        List<Map<String, dynamic>>? projectFacilities;
        if (stateData?.modelMap != null) {
          projectFacilities = stateData!.modelMap['ProjectFacilityModel'];
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
        if (stateData?.modelMap != null) {
          productVariants = stateData!.modelMap['ProductVariantModel'];
        }
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

    /// True once the registration health-talk checklist has been submitted
    /// for this household.
    ///
    /// The checklist persists its answers as ACTION1..ACTIONn keys in the
    /// household's additionalFields (via beneficiaryRegistration's
    /// fallbackModel). Any such key means the user has already been through
    /// the checklist, so the entry point must not offer it again - without
    /// this, the acknowledgement screen's "Household Details" link returns to
    /// householdOverview with Save still enabled, and the checklist can be
    /// filled over and over in a loop.
    ///
    /// Usage: "{{fn:isChecklistCompleted(contextData.0.household.HouseholdModel.additionalFields.fields)}}"
    FunctionRegistry.register('isChecklistCompleted', (args, stateData) {
      if (args.isEmpty || args.first == null) return false;
      final raw = args.first;

      bool isActionKey(dynamic key) {
        final name = key?.toString().trim().toUpperCase() ?? '';
        if (!name.startsWith('ACTION')) return false;
        // ACTION followed by digits only, so unrelated keys that merely begin
        // with "action" cannot satisfy this.
        final suffix = name.substring('ACTION'.length);
        return suffix.isNotEmpty && int.tryParse(suffix) != null;
      }

      // additionalFields.fields is a list of {key, value} in API payloads and
      // a list of AdditionalField objects in the app model; the interpolation
      // layer may also hand this over already flattened to a map.
      if (raw is Map) {
        return raw.keys.any(isActionKey);
      }
      if (raw is List) {
        for (final field in raw) {
          if (field is Map) {
            if (isActionKey(field['key'])) return true;
            continue;
          }
          try {
            if (isActionKey((field as dynamic).key)) return true;
          } catch (_) {
            // Not a key/value shaped entry - ignore.
          }
        }
      }
      return false;
    });

    /// The id this facility's stock should be booked against.
    ///
    /// Warehouse-manager style roles are mapped to a real facility, so the
    /// facility selected on the form is correct for them. A Distributor (and
    /// therefore Registrar+Distributor, which also holds DISTRIBUTOR) has no
    /// facility of its own - its stock is keyed by the user's uuid, which is
    /// the same convention getReportFacilityId already applies when reading
    /// these records back. Writing one convention and querying the other is
    /// what leaves a distributor's stock out of its own balance.
    ///
    /// Usage: "{{fn:getStockFacilityId(warehouseDetails.facilityToWhich)}}"
    FunctionRegistry.register('getStockFacilityId', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .any((role) => role.code == RolesType.distributor.toValue());
      if (isDistributor) return context.loggedInUserUuid ?? '';
      final selected = args.isNotEmpty ? args.first?.toString().trim() : null;
      return (selected == null || selected.isEmpty || selected == 'null')
          ? ''
          : selected;
    });

    /// Human-readable name for the facility a stock record transacted with,
    /// stored alongside the id so a report row stays readable even when the
    /// facility list is not loaded. Facility names are localised as
    /// FAC_<facilityId>; DELIVERY_TEAM is a synthetic party with its own
    /// code. Returns '' rather than a raw uuid when nothing resolves, so the
    /// row hides instead of showing an opaque id.
    ///
    /// Usage: "{{fn:getTransactingFacilityName(stockDetails.facilityFromWhich)}}"
    FunctionRegistry.register('getTransactingFacilityName', (args, stateData) {
      final raw = args.isNotEmpty ? args.first?.toString().trim() : null;
      if (raw == null || raw.isEmpty || raw == 'null') return '';
      if (raw.toUpperCase() == 'DELIVERY_TEAM') return 'DELIVERY_TEAM';
      // Facility ids are localised through the FAC_ prefix; a uuid-shaped
      // value is a staff/user party and has no facility name.
      final isUuidLike = raw.contains('-') && !raw.startsWith('F-');
      return isUuidLike ? '' : 'FAC_$raw';
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
      if (modelKey.isEmpty || stateData?.modelMap == null) return false;
      final results = stateData!.modelMap[modelKey];
      return results != null && results.isNotEmpty;
    });
  }

  void _registerStockFunctions() {
    // Returns true when at least one product has a balance > 0.
    // Fail-open: returns true when the cache has no facility set yet, OR
    // when it holds a DIFFERENT facility's balances - e.g. right after a
    // role switch on the same device, before stock_balance_card.dart's next
    // refresh repopulates the cache for the newly logged-in facility.
    FunctionRegistry.register('hasStockForRegistration', (args, stateData) {
      final cache = StockBalanceCache.instance;
      final currentFacilityId = _resolveUserFacilityId(stateData);
      if (cache.facilityId.isEmpty ||
          (currentFacilityId.isNotEmpty &&
              cache.facilityId != currentFacilityId)) {
        return true;
      }
      if (cache.cache.isEmpty) return false;
      final s = cache.cache.values.any((balance) => balance > 0);
      print(s);
      print(cache.cache.values.any((balance) => balance > 0));
      return cache.cache.values.any((balance) => balance > 0);
    });

    FunctionRegistry.register("isClosedHousehold", (args, stateData) {
      if (args.isEmpty || args.first == null) return false;
      final tasks = args.first;

      if (tasks is! List || tasks.isEmpty) return false;

      String? getStatus(dynamic task) {
        if (task is Map) return task['status']?.toString()?.toUpperCase();
        try {
          return (task as dynamic).status?.toString()?.toUpperCase();
        } catch (_) {
          return null;
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
      if (args.isEmpty || args.first == null) return false;
      final tasks = args.first;

      if (tasks is! List || tasks.isEmpty) return false;

      String? getStatus(dynamic task) {
        if (task is Map) return task['status']?.toString()?.toUpperCase();
        try {
          return (task as dynamic).status?.toString()?.toUpperCase();
        } catch (_) {
          return null;
        }
      }

      return getStatus(tasks.last) == 'CLOSED_HOUSEHOLD';
    });

    // Used by the searchBeneficiary OPEN handler to decide whether a
    // household must be routed through the caregiverConsent page before
    // household details/overview can be shown. Covers both Map-shaped and
    // model-object-shaped additionalFields since the engine can materialize
    // item.HouseholdModel either way.
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
          additionalFields = null;
        }
      }
      if (additionalFields == null) return true;

      // searchBeneficiary's item.HouseholdModel is a raw SQL join row, not a
      // materialized model - additionalFields there is a JSON-encoded TEXT
      // column (see household.dart's Drift table), not a parsed Map. Without
      // this decode step every household - closed or not, consent captured
      // or not - fell through to the catch blocks below and this always
      // returned true, routing every search-reopen through this branch.
      if (additionalFields is String) {
        if (additionalFields.isEmpty) return true;
        try {
          additionalFields = jsonDecode(additionalFields);
        } catch (_) {
          return true;
        }
      }

      dynamic consentValue;
      if (additionalFields is Map) {
        final fields = additionalFields['fields'];
        if (fields is List) {
          for (final f in fields) {
            final key = (f is Map) ? f['key'] : (f as dynamic).key;
            if (key == 'caregiverConsent') {
              consentValue = (f is Map) ? f['value'] : (f as dynamic).value;
              break;
            }
          }
        } else {
          consentValue = additionalFields['caregiverConsent'];
        }
      } else {
        try {
          final fields = (additionalFields as dynamic).fields;
          if (fields is List) {
            for (final f in fields) {
              final key = (f is Map) ? f['key'] : (f as dynamic).key;
              if (key == 'caregiverConsent') {
                consentValue = (f is Map) ? f['value'] : (f as dynamic).value;
                break;
              }
            }
          }
        } catch (_) {
          consentValue = null;
        }
      }

      return consentValue == null || consentValue.toString().isEmpty;
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
      final currentFacilityId = _resolveUserFacilityId(stateData);
      if (cache.facilityId.isEmpty ||
          (currentFacilityId.isNotEmpty &&
              cache.facilityId != currentFacilityId)) {
        return true;
      }
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
      final currentFacilityId = _resolveUserFacilityId(stateData);
      if (cache.facilityId.isEmpty ||
          (currentFacilityId.isNotEmpty &&
              cache.facilityId != currentFacilityId)) {
        return true;
      }

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
          if (field is Map && field['key'] == 'stockEntryType') {
            return field['value']?.toString().toUpperCase() ?? '';
          }
        }
      }
      return '';
    }

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

    /// Display form for a STAFF (delivery team / CDD) party: the username
    /// alongside the id it is recorded against, e.g. "jdoe | <uuid>". The id
    /// is what every transaction and report keys on, so showing the name
    /// alone makes rows impossible to cross-reference; showing the id alone
    /// is meaningless to the user. Degrades to whichever half is available.
    String teamPartyDisplay(String teamName, String id) {
      final name = teamName.trim();
      final identifier = id.trim();
      if (name.isEmpty) return identifier;
      if (identifier.isEmpty) return name;
      return '$name | $identifier';
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
            return teamPartyDisplay(teamName, args[1]?.toString() ?? '');
          }
          return withFacilityPrefix(args[1]);
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          if (receiverType == 'STAFF') {
            return teamPartyDisplay(teamName, args[2]?.toString() ?? '');
          }
          return withFacilityPrefix(args[2]);
        default:
          if (senderType == 'STAFF') {
            return teamPartyDisplay(teamName, args[1]?.toString() ?? '');
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
            return teamPartyDisplay(teamName, args[2]?.toString() ?? '');
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
            return teamPartyDisplay(teamName, args[2]?.toString() ?? '');
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
