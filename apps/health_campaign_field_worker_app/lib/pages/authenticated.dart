import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:attendance_management/data/repositories/oplog/oplog.dart'
    as am_oplog;
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:isar/isar.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_showcase/showcase_widget.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/component_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_loader.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/helper_widget/digit_profile.dart';
import 'package:digit_ui_components/widgets/molecules/hamburger.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:isar/isar.dart';
import 'package:location/location.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_form/survey_form.dart';
import 'package:sync_service/sync_service_lib.dart';
import 'package:transit_post/data/repositories/local/user_action.dart';
import 'package:transit_post/data/repositories/remote/user_action.dart';

import 'package:attendance_management/attendance_management.dart';
import 'package:digit_face_verification/digit_face_verification.dart';

import '../blocs/app_initialization/app_initialization.dart';
import '../blocs/auth/auth.dart';
import '../blocs/face_auth/face_gate_bloc.dart';
import '../blocs/face_auth/reverification_bloc.dart';
import '../blocs/hf_referral_downsync/hf_referral_downsync.dart';
import '../blocs/localization/app_localization.dart';
import '../blocs/localization/localization.dart';
import '../blocs/projects_beneficiary_downsync/project_beneficiaries_downsync.dart';
import '../blocs/stock_downsync/stock_downsync.dart';
import '../data/local_store/no_sql/schema/service_registry.dart';
import '../data/local_store/secure_store/secure_store.dart';
import '../blocs/push_notification/push_notification.dart';
import '../data/local_store/app_shared_preferences.dart';
import '../data/local_store/no_sql/schema/app_configuration.dart';
import '../data/remote_client.dart';
import '../data/repositories/remote/bandwidth_check.dart';
import '../models/downsync/downsync.dart';
import '../models/entities/notification_data.dart';
import '../models/entities/roles_type.dart';
import '../notification_handlers/notification_handler.dart';
import '../notification_service.dart';
import '../router/app_router.dart';
import '../services/face_auth_config.dart';
import '../services/reverification_scheduler.dart';
import '../services/worker_registry_service.dart';
import '../widgets/face_auth/face_verification_dialog.dart';
import '../widgets/face_auth/reverification_popup.dart';
import '../router/authenticated_route_observer.dart';
import '../utils/environment_config.dart';
import '../utils/i18_key_constants.dart' as i18;
import '../utils/utils.dart';
import '../widgets/error_screen.dart';
import 'error_boundary.dart';

@RoutePage()
class AuthenticatedPageWrapper extends StatefulWidget {
  const AuthenticatedPageWrapper({super.key});

  @override
  State<AuthenticatedPageWrapper> createState() =>
      _AuthenticatedPageWrapperState();
}

class _AuthenticatedPageWrapperState extends State<AuthenticatedPageWrapper>
    with WidgetsBindingObserver {
  final StreamController<bool> _drawerVisibilityController =
      StreamController.broadcast();
  StreamController<HFReferralProgressData> _hfReferralProgress =
      StreamController<HFReferralProgressData>.broadcast();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOfflineDialogShowing = false;
  bool _hasCheckedEnrollment = false;

  FaceAuthConfig _faceAuthConfig = const FaceAuthConfig();
  bool _configFromRegister = false;
  bool _coWorkerEmbeddingsPrefetched = false;

  ReVerificationScheduler? _reVerificationScheduler;
  StreamSubscription<ReVerificationTrigger>? _reVerificationSubscription;
  StreamSubscription<ReVerificationState>? _reVerStateSubscription;
  ReVerificationBloc? _reVerificationBloc;
  // Held so we can push MDMS-derived threshold/maxAttempts into the live bloc
  // when _initConfigFromRegister resolves AFTER the BlocProvider has created it.
  FaceGateBloc? _faceGateBloc;
  /// Index of the trigger currently being prompted to the user. Cleared
  /// when the trigger reaches a terminal state (verified / missed). The
  /// bloc tracks popup time but not the schedule index, so we hold it here
  /// to feed into ReVerificationScheduler.markCompleted(...).
  int? _activeTriggerIndex;
  final StreamController<List<DateTime>> _scheduleController =
      StreamController<List<DateTime>>.broadcast();
  final ValueNotifier<ReVerificationState?> _reVerStateNotifier =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    _startReVerificationScheduler();
    // When face enrollment finishes (notifier flips true → false) regenerate
    // the schedule so the user gets prompts at +5/+10/+15 min relative to
    // when they finished enrolling, not relative to app launch. This avoids
    // the case where the early scheduled triggers fired during enrollment
    // and got silently consumed by _dispatchTrigger's enrollment check.
    faceEnrollmentActiveNotifier.addListener(_onEnrollmentActiveChanged);
  }

  bool _lastEnrollmentActive = false;
  void _onEnrollmentActiveChanged() async {
    final now = faceEnrollmentActiveNotifier.value;
    if (_lastEnrollmentActive == true && now == false) {
      debugPrint(
        'AuthenticatedPage: enrollment finished — regenerating reverification schedule',
      );
      try {
        await _reVerificationScheduler?.regenerate();
        if (mounted && _reVerificationScheduler != null) {
          _scheduleController.add(_reVerificationScheduler!.currentSchedule);
        }
      } catch (e) {
        debugPrint(
            'AuthenticatedPage: failed to regenerate schedule after enrollment: $e');
      }
    }
    _lastEnrollmentActive = now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reVerificationScheduler?.checkNow();
    }
  }

  void _checkFaceEnrollment() {
    // Scheduler is now started in initState; nothing to do here.
  }

  Future<void> _initConfigFromRegister() async {
    if (_configFromRegister) return;
    try {
      if (!mounted) return;
      final individualId = context.loggedInIndividualIdOrNull;
      if (individualId == null) return;

      final registerRepo = context.repository<AttendanceRegisterModel,
          AttendanceRegisterSearchModel>();
      final now = DateTime.now();
      final registers = await registerRepo
          .search(AttendanceRegisterSearchModel(attendeeId: individualId));
      if (!mounted) return;

      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd =
          todayStart + const Duration(days: 1).inMilliseconds - 1;

      final mdmsState =
          context.read<AppInitializationBloc>().state as AppInitialized?;
      final mdmsFaceConfig = mdmsState?.appConfiguration.faceAuthMdmsConfig;
      for (final r in registers) {
        final start = r.startDate ?? 0;
        final end = r.endDate ?? 0;
        if (start <= todayEnd && end >= todayStart) {
          _configFromRegister = true;
          _faceAuthConfig = _buildConfigFromRegister(r, mdmsConfig: mdmsFaceConfig);
          break;
        }
      }

      // If no active register matched today, MDMS is the only authoritative
      // source for the re-verification window. Apply it directly so endHour /
      // startHour / promptCount / minGap aren't silently left at their compiled
      // defaults (startHour=8, endHour=18) when MDMS says otherwise.
      if (!_configFromRegister && mdmsFaceConfig != null) {
        final d = _faceAuthConfig;
        _faceAuthConfig = FaceAuthConfig(
          startHour: mdmsFaceConfig.startHour ?? d.startHour,
          endHour: mdmsFaceConfig.endHour ?? d.endHour,
          promptCount: mdmsFaceConfig.promptCount ?? d.promptCount,
          minGapMinutes: mdmsFaceConfig.minGapMinutes ?? d.minGapMinutes,
          countdownDuration: Duration(
              minutes: mdmsFaceConfig.countdownDurationMinutes ??
                  d.countdownDuration.inMinutes),
          maxFaceAttempts: mdmsFaceConfig.maxFaceAttempts ?? d.maxFaceAttempts,
          faceMatchThreshold:
              mdmsFaceConfig.faceMatchThreshold ?? d.faceMatchThreshold,
        );
        debugPrint(
          'AuthenticatedPage: no active register today — applied MDMS face '
          'config (startHour=${_faceAuthConfig.startHour} '
          'endHour=${_faceAuthConfig.endHour} '
          'promptCount=${_faceAuthConfig.promptCount})',
        );
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _initConfigFromRegister failed: $e');
    }
  }

  Future<void> _startReVerificationScheduler({bool immediateFirstTrigger = false}) async {
    if (_reVerificationScheduler != null) return;

    try {
      final isSupervisor =
          context.isTeamSupervisorRole || context.isDistrictSupervisorRole;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('face_reverify_skip', isSupervisor);
      if (isSupervisor) {
        return;
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: supervisor flag write failed: $e');
    }

    await _initConfigFromRegister();

    // _initConfigFromRegister may have updated _faceAuthConfig with MDMS /
    // register-derived values AFTER the BlocProvider already constructed the
    // bloc with the initState default. Push the latest config into the bloc
    // so the next prompt's countdown duration / threshold / attempts match
    // what was just resolved.
    if (_reVerificationBloc != null && !_reVerificationBloc!.isClosed) {
      _reVerificationBloc!.updateConfig(_faceAuthConfig);
      debugPrint(
          'AuthenticatedPage: pushed initial resolved config to bloc — '
          'countdownMin=${_faceAuthConfig.countdownDuration.inMinutes}');
    }

    // Same race for FaceGateBloc — push MDMS-derived threshold/maxAttempts
    // so login-time face verification uses the right cutoff instead of the
    // constructor-time defaults.
    if (_faceGateBloc != null && !_faceGateBloc!.isClosed) {
      _faceGateBloc!.updateConfig(
        threshold: _faceAuthConfig.faceMatchThreshold,
        maxAttempts: _faceAuthConfig.maxFaceAttempts,
      );
      debugPrint(
          'AuthenticatedPage: pushed initial resolved config to FaceGateBloc — '
          'threshold=${_faceAuthConfig.faceMatchThreshold} '
          'maxAttempts=${_faceAuthConfig.maxFaceAttempts}');
    }

    _reVerificationScheduler = ReVerificationScheduler(config: _faceAuthConfig);
    _reVerificationScheduler!.isForeground = () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _reVerificationScheduler!.start(immediateFirstTrigger: immediateFirstTrigger).then((_) {
      if (mounted) {
        _scheduleController.add(_reVerificationScheduler!.currentSchedule);
        _checkNotificationLaunch();
      }
    }).catchError((e) {
      debugPrint('AuthenticatedPage: scheduler start failed: $e');
    });
    _reVerificationSubscription =
        _reVerificationScheduler!.triggers.listen((trigger) {
      _dispatchTrigger(trigger);
    });
  }

  Future<void> _checkNotificationLaunch() async {
    try {
      final details = await NotificationService()
          .flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final payload = details.notificationResponse?.payload;
      if (payload == null ||
          !payload.startsWith(NotificationService.reVerifyPayloadPrefix)) return;
      final indexStr =
          payload.substring(NotificationService.reVerifyPayloadPrefix.length);
      final index = int.tryParse(indexStr);
      if (index == null) return;
      if (mounted) {
        _dispatchTrigger(ReVerificationTrigger(
          scheduledTime: DateTime.now(),
          triggerIndex: index,
        ));
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _checkNotificationLaunch failed: $e');
    }
  }

  void _markTriggerHandledByApp(int triggerIndex) {
    SharedPreferences.getInstance().then((prefs) {
      final existing =
          (prefs.getStringList('face_reverification_bg_notified') ?? [])
              .toSet();
      existing.add(triggerIndex.toString());
      prefs.setStringList(
          'face_reverification_bg_notified', existing.toList());
    }).catchError(
        (e) => debugPrint('_markTriggerHandledByApp: $e'));
  }

  void _dispatchTrigger(ReVerificationTrigger trigger) async {
    final now = DateTime.now();
    debugPrint('──────────────────────────────────────────────');
    debugPrint('_dispatchTrigger #${trigger.triggerIndex} at $now '
        '(scheduled=${trigger.scheduledTime}, '
        'delay=${now.difference(trigger.scheduledTime).inSeconds}s)');
    debugPrint('  topRoute=${context.router.topRoute.name}');

    try {
      final isar = context.read<Isar>();
      final repository = FaceEmbeddingRepository(isar);
      final enrollmentCount = await repository.count();
      debugPrint('  [Guard 1] enrollmentCount=$enrollmentCount');
      if (enrollmentCount == 0) {
        // Defer — once enrollment exists, _checkTriggers will replay this.
        debugPrint('  → DEFER (Guard 1): no face enrollment yet — markPending');
        _reVerificationScheduler?.markPending(trigger.triggerIndex);
        return;
      }
    } catch (e) {
      debugPrint('  [Guard 1] enrollment check threw: $e — markPending');
      _reVerificationScheduler?.markPending(trigger.triggerIndex);
      return;
    }

    if (!mounted) {
      debugPrint('  → ABORT: not mounted after Guard 1');
      return;
    }

    try {
      final individualId = context.loggedInIndividualIdOrNull;
      debugPrint('  [Guard 2] individualId=$individualId');
      if (individualId != null) {
        final registerRepo = AttendanceLocalRepository(
          context.read<LocalSqlDataStore>(),
          am_oplog.AttendanceOpLogManager(context.read<Isar>()),
        );
        final registers = await registerRepo.search(
          AttendanceRegisterSearchModel(attendeeId: individualId),
        );
        debugPrint('  [Guard 2] registers found locally: ${registers.length}');

        final todayStart =
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final todayEnd =
            todayStart + const Duration(days: 1).inMilliseconds - 1;

        AttendanceRegisterModel? activeRegister;
        for (final r in registers) {
          final start = r.startDate ?? 0;
          final end = r.endDate ?? 0;
          final overlap = start <= todayEnd && end >= todayStart;
          debugPrint('  [Guard 2] register id=${r.id} '
              'start=${DateTime.fromMillisecondsSinceEpoch(start)} '
              'end=${DateTime.fromMillisecondsSinceEpoch(end)} '
              'overlapsToday=$overlap');
          if (overlap) {
            activeRegister = r;
            break;
          }
        }

        if (activeRegister == null) {
          if (registers.isNotEmpty) {
            // Registers exist locally but none overlap today — defer until
            // a valid one appears (e.g. boundary change or new day).
            debugPrint(
                '  → DEFER (Guard 2): registers exist but none active today — markPending');
            _reVerificationScheduler?.markPending(trigger.triggerIndex);
            return;
          }
          // No registers at all — fail-open so distributors without attendance
          // registers are not permanently blocked from re-verification.
          debugPrint(
              '  → PASS (Guard 2): no registers locally — proceeding with default config');
        }
        if (activeRegister != null) {
          debugPrint('  [Guard 2] active register id=${activeRegister.id} ✓');
        }

        if (!_configFromRegister && activeRegister != null) {
          _configFromRegister = true;
          // Pull MDMS config from the bloc again — it may have finished
          // loading after _startReVerificationScheduler's initial read,
          // and we want the latest MIN_GAP_MINUTES / PROMPT_COUNT / etc.
          final mdmsState =
              context.read<AppInitializationBloc>().state as AppInitialized?;
          final mdmsFaceConfig =
              mdmsState?.appConfiguration.faceAuthMdmsConfig;
          final newConfig = _buildConfigFromRegister(
            activeRegister,
            mdmsConfig: mdmsFaceConfig,
          );
          final configChanged =
              newConfig.startHour != _faceAuthConfig.startHour ||
              newConfig.endHour != _faceAuthConfig.endHour ||
              newConfig.promptCount != _faceAuthConfig.promptCount ||
              newConfig.minGapMinutes != _faceAuthConfig.minGapMinutes;
          if (!_coWorkerEmbeddingsPrefetched) {
            _prefetchCoWorkerEmbeddings(context);
          }

          if (configChanged) {
            final newDayEnd = DateTime(now.year, now.month, now.day, newConfig.endHour);
            if (now.isAfter(newDayEnd)) {
              _restartSchedulerWithConfig(newConfig, immediateFirstTrigger: false);
              return;
            } else {
              _restartSchedulerWithConfig(newConfig);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: attendance check threw: $e — failing open');
    }

    if (!mounted) {
      debugPrint('  → ABORT: not mounted after Guard 2/3');
      return;
    }

    final topRoute = context.router.topRoute.name;
    debugPrint('  [Guard 4] topRoute=$topRoute');
    if (topRoute == FaceGateRoute.name ||
        topRoute == NonMobileFaceEnrollRoute.name) {
      // Defer — the user is mid-login-gate / mid-enrollment. Mark pending so
      // _checkTriggers replays this trigger once they leave that route.
      debugPrint('  → DEFER (Guard 4): on $topRoute — markPending');
      _reVerificationScheduler?.markPending(trigger.triggerIndex);
      return;
    }

    if (_reVerificationBloc != null && !_reVerificationBloc!.isClosed) {
      debugPrint('  → DISPATCHED to ReVerificationBloc ✓');
      _activeTriggerIndex = trigger.triggerIndex;
      _reVerificationBloc!.add(
        ReVerificationEvent.triggered(trigger: trigger),
      );
      _markTriggerHandledByApp(trigger.triggerIndex);
      // Dispatch succeeded — clear any pending-replay marker so the next
      // _checkTriggers tick doesn't re-emit this trigger.
      _reVerificationScheduler?.clearPending();
      debugPrint('──────────────────────────────────────────────');
    } else {
      debugPrint('  → BLOC NULL or CLOSED, retrying in 1s');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _dispatchTrigger(trigger);
      });
    }
    if (mounted) {
      _scheduleController.add(_reVerificationScheduler!.currentSchedule);
    }
  }

  FaceAuthConfig _buildConfigFromRegister(
    AttendanceRegisterModel register, {
    FaceAuthMdmsConfig? mdmsConfig,
  }) {
    const d = FaceAuthConfig();
    final details = register.additionalDetails;
    final cfg = FaceAuthConfig(
      startHour: (details?['startHour'] as num?)?.toInt() ?? mdmsConfig?.startHour ?? d.startHour,
      endHour: (details?['endHour'] as num?)?.toInt() ?? mdmsConfig?.endHour ?? d.endHour,
      promptCount: mdmsConfig?.promptCount ?? d.promptCount,
      minGapMinutes: mdmsConfig?.minGapMinutes ?? d.minGapMinutes,
      countdownDuration: Duration(minutes: mdmsConfig?.countdownDurationMinutes ?? d.countdownDuration.inMinutes),
      maxFaceAttempts: mdmsConfig?.maxFaceAttempts ?? d.maxFaceAttempts,
      faceMatchThreshold: mdmsConfig?.faceMatchThreshold ?? d.faceMatchThreshold,
    );
    debugPrint(
      'FaceAuthConfig (resolved): '
      'startHour=${cfg.startHour} endHour=${cfg.endHour} '
      'promptCount=${cfg.promptCount} minGapMinutes=${cfg.minGapMinutes} '
      'countdownMin=${cfg.countdownDuration.inMinutes} '
      'maxAttempts=${cfg.maxFaceAttempts} threshold=${cfg.faceMatchThreshold} '
      'sources={register=${details != null}, mdms=${mdmsConfig != null}}',
    );
    return cfg;
  }

  Future<void> _prefetchCoWorkerEmbeddings(BuildContext context) async {
    if (_coWorkerEmbeddingsPrefetched) return;
    try {
      if (!mounted) return;
      final individualId = context.loggedInIndividualIdOrNull;
      if (individualId == null) return;

      final repository = context.read<FaceEmbeddingRepository>();
      // Build AttendanceLocalRepository directly to avoid the generic-type
      // provider mismatch between digit_data_model and attendance_management.
      final registerRepo = AttendanceLocalRepository(
        context.read<LocalSqlDataStore>(),
        am_oplog.AttendanceOpLogManager(context.read<Isar>()),
      );
      final individualRepo =
          context.repository<IndividualModel, IndividualSearchModel>();

      final registers = await registerRepo
          .search(AttendanceRegisterSearchModel(attendeeId: individualId));
      if (!mounted) return;

      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds - 1;

      for (final r in registers) {
        final start = r.startDate ?? 0;
        final end = r.endDate ?? 0;
        if (!(start <= todayEnd && end >= todayStart)) continue;

        _coWorkerEmbeddingsPrefetched = true;

        final eligibleRawIds = (r.attendees ?? <AttendeeModel>[])
            .where((a) =>
                a.denrollmentDate == null ||
                (a.denrollmentDate ?? now.millisecondsSinceEpoch) >=
                    now.millisecondsSinceEpoch)
            .map((a) => a.individualId)
            .where((id) => id != null && id!.isNotEmpty)
            .cast<String>()
            .toList();

        if (eligibleRawIds.isEmpty) break;

        final individuals = await individualRepo
            .search(IndividualSearchModel(id: eligibleRawIds));
        if (!mounted) return;

        final coWorkerIds = individuals
            .where((i) =>
                i.id != null && i.id!.isNotEmpty && i.id != individualId)
            .map((i) => i.id!)
            .toList();

        if (coWorkerIds.isEmpty) break;

        final service = WorkerRegistryService(
          dio: DioClient().dio,
          tenantId: envConfig.variables.tenantId,
        );

        for (final id in coWorkerIds) {
          if (!mounted) return;
          final hasLocal = await repository.hasEmbedding(id);
          if (!hasLocal) {
            await service.syncEnrollmentFromRegistry(
                individualId: id, repository: repository);
          }
        }
        break;
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _prefetchCoWorkerEmbeddings failed: $e');
    }
  }

  void _restartSchedulerWithConfig(FaceAuthConfig newConfig, {bool immediateFirstTrigger = true}) {
    _reVerificationSubscription?.cancel();
    _reVerificationSubscription = null;
    _reVerificationScheduler?.dispose();
    _reVerificationScheduler = null;
    _faceAuthConfig = newConfig;
    // Push the new config into the live bloc so countdownDuration / threshold /
    // maxFaceAttempts etc. take effect on the very next prompt. Without this
    // the bloc keeps its constructor-time config and the timer stays at the
    // old countdown duration even after MDMS updates land.
    _reVerificationBloc?.updateConfig(newConfig);
    _faceGateBloc?.updateConfig(
      threshold: newConfig.faceMatchThreshold,
      maxAttempts: newConfig.maxFaceAttempts,
    );
    debugPrint(
        'AuthenticatedPage: pushed new config to bloc — '
        'countdownMin=${newConfig.countdownDuration.inMinutes} '
        'threshold=${newConfig.faceMatchThreshold} '
        'maxAttempts=${newConfig.maxFaceAttempts}');
    _startReVerificationScheduler(immediateFirstTrigger: immediateFirstTrigger);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    faceEnrollmentActiveNotifier.removeListener(_onEnrollmentActiveChanged);
    _reVerificationSubscription?.cancel();
    _reVerStateSubscription?.cancel();
    _reVerStateNotifier.dispose();
    _reVerificationScheduler?.dispose();
    _scheduleController.close();
    _connectivitySubscription.cancel();
    _drawerVisibilityController.close();
    _hfReferralProgress.close();
    super.dispose();
  }

  bool _lastConnectivityOnline = true;
  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isOnline = result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
    final isOffline = !isOnline;

    if (isOffline && !_isOfflineDialogShowing && mounted) {
      _showNoInternetDialog();
    } else if (!isOffline && _isOfflineDialogShowing && mounted) {
      _dismissNoInternetDialog();
    }

    // Retry the worker-registry queue on EVERY offline → online transition,
    // not just when the no-internet dialog is dismissed. Silent offline
    // failures during enrollment never showed the dialog, so the dialog-
    // dismiss branch wouldn't catch them. Tracking _lastConnectivityOnline
    // ourselves makes the retry path independent of dialog state.
    if (isOnline && !_lastConnectivityOnline && mounted) {
      debugPrint(
          'AuthenticatedPage: connectivity restored — retrying pending worker registry sync');
      _retryPendingWorkerRegistrySync();
    }
    _lastConnectivityOnline = isOnline;
  }

  Future<void> _retryPendingWorkerRegistrySync() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Drain BOTH the legacy single-string key (FaceGate writes here) and the
      // new list key (NonMobileFaceEnroll writes here) so distributor + co-worker
      // offline enrollments are both retried.
      final pendingIds = <String>{};
      final legacySingle = prefs.getString('face_registry_sync_pending');
      if (legacySingle != null && legacySingle.isNotEmpty) {
        pendingIds.add(legacySingle);
      }
      pendingIds.addAll(
          prefs.getStringList('face_registry_sync_pending_ids') ?? const []);
      if (pendingIds.isEmpty) return;
      if (!mounted) return;

      final isar = context.read<Isar>();
      final repository = FaceEmbeddingRepository(isar);
      final service = WorkerRegistryService(
        dio: DioClient().dio,
        tenantId: envConfig.variables.tenantId,
      );

      final remaining = <String>{};
      for (final id in pendingIds) {
        final ok = await service.updateWorkerWithFaceEnrollment(
          individualId: id,
          repository: repository,
        );
        if (ok) {
          debugPrint(
              'AuthenticatedPage: worker registry sync retry succeeded for $id');
        } else {
          debugPrint(
              'AuthenticatedPage: worker registry sync retry still failing for $id (network) — keeping in queue');
          remaining.add(id);
        }
      }

      // Persist what's left so the next connectivity-restore tick keeps trying.
      await prefs.setStringList(
          'face_registry_sync_pending_ids', remaining.toList());
      // Clean up the legacy single-string slot regardless — it's been absorbed.
      await prefs.remove('face_registry_sync_pending');
    } catch (e) {
      debugPrint('AuthenticatedPage: worker registry sync retry failed: $e');
    }
  }

  void _showNoInternetDialog() {
    _isOfflineDialogShowing = true;
    showCustomPopup(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Popup(
        title: AppLocalizations.of(context).translate(
          i18.common.connectionLabel,
        ),
        description: AppLocalizations.of(context).translate(
          i18.common.connectionContent,
        ),
        actions: [
          DigitButton(
            label: AppLocalizations.of(context).translate(
              i18.common.coreCommonOk,
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _isOfflineDialogShowing = false;
            },
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );
  }

  void _dismissNoInternetDialog() {
    if (_isOfflineDialogShowing) {
      Navigator.of(context, rootNavigator: true).pop();
      _isOfflineDialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ShowcaseWidget(
      enableAutoScroll: true,
      builder: Builder(
        builder: (context) {
          return StreamBuilder<bool>(
            stream: _drawerVisibilityController.stream,
            builder: (context, snapshot) {
              final showDrawer = snapshot.data ?? false;

              return Portal(
                child: Scaffold(
                  backgroundColor: theme.colorTheme.generic.background,
                  appBar: AppBar(
                    backgroundColor: theme.colorTheme.primary.primary2,
                    foregroundColor: theme.colorTheme.paper.primary,
                    title: ValueListenableBuilder<ReVerificationState?>(
                      valueListenable: _reVerStateNotifier,
                      builder: (context, state, _) {
                        if (state is! ReVerificationPromptedState) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'Attempt ${state.iteration} of ${state.maxIterations}',
                          style: TextStyle(
                            color: theme.colorTheme.paper.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    actions: showDrawer
                        ? [
                            BlocBuilder<BoundaryBloc, BoundaryState>(
                              builder: (ctx, state) {
                                final selectedBoundary = ctx.boundaryOrNull;

                                if (selectedBoundary == null) {
                                  return const SizedBox.shrink();
                                } else {
                                  LocalizationParams()
                                      .setCode([selectedBoundary.code!, i18.common.coreCommonSubmit]);
                                  final boundaryName =
                                      AppLocalizations.of(context).translate(
                                    selectedBoundary.code ??
                                        i18.projectSelection.onProjectMapped,
                                  );

                                  final theme = Theme.of(context);

                                  return GestureDetector(
                                    onTap: () {
                                      ctx.router.replaceAll([
                                        BoundarySelectionRoute(),
                                      ]);
                                    },
                                    child: Container(
                                      padding:
                                          const EdgeInsets.only(right: spacer2),
                                      width: MediaQuery.of(context).size.width -
                                          60,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                boundaryName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: theme
                                                      .colorTheme.paper.primary,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down_outlined,
                                              color: theme
                                                  .colorTheme.paper.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ]
                        : null,
                  ),
                  drawer: showDrawer ? drawerWidget(context) : null,
                  body: MultiRepositoryProvider(
                    providers: [
                      RepositoryProvider<FaceModelService>(
                        create: (_) => FaceModelService()..initialize(),
                      ),
                      RepositoryProvider<FaceEmbeddingRepository>(
                        create: (ctx) => FaceEmbeddingRepository(
                          ctx.read<Isar>(),
                        ),
                      ),
                    ],
                    child: MultiBlocProvider(
                    providers: [
                      BlocProvider(
                        create: (ctx) {
                          final mdmsState = context
                              .read<AppInitializationBloc>()
                              .state as AppInitialized?;
                          final faceMdms =
                              mdmsState?.appConfiguration.faceAuthMdmsConfig;
                          _faceGateBloc = FaceGateBloc(
                            repository: ctx.read<FaceEmbeddingRepository>(),
                            workerRegistryService: WorkerRegistryService(
                              dio: DioClient().dio,
                              tenantId: envConfig.variables.tenantId,
                            ),
                            similarityThreshold: _faceAuthConfig.faceMatchThreshold,
                            maxAttempts: _faceAuthConfig.maxFaceAttempts,
                          );
                          return _faceGateBloc!;
                        },
                      ),
                      BlocProvider(
                        create: (ctx) => FaceVerificationBloc(
                          faceModelService: ctx.read<FaceModelService>(),
                          embeddingRepository: ctx.read<FaceEmbeddingRepository>(),
                          // Pass MDMS-derived threshold so the standalone
                          // FaceVerificationView (used by some flows) uses the
                          // same cutoff as login + re-verification, instead of
                          // DistanceMetrics.defaultThreshold.
                          similarityThreshold: _faceAuthConfig.faceMatchThreshold,
                        ),
                      ),
                      BlocProvider(
                        create: (_) => LivenessBloc(),
                      ),
                      BlocProvider(
                        lazy: false,
                        create: (ctx) {
                          _reVerificationBloc = ReVerificationBloc(
                            repository: ctx.read<FaceEmbeddingRepository>(),
                            config: _faceAuthConfig,
                            currentUserIndividualId:
                                ctx.loggedInIndividualIdOrNull ?? '',
                          );
                          _reVerStateSubscription?.cancel();
                          _reVerStateSubscription =
                              _reVerificationBloc!.stream.listen((state) {
                            _reVerStateNotifier.value = state;
                            // When a prompt reaches a terminal state, persist
                            // it so the trigger isn't re-fired on next app
                            // restart. Without this the scheduler treats the
                            // trigger as pending forever.
                            final terminal = state.maybeWhen(
                              verified: (_, __) => true,
                              missed: (_) => true,
                              orElse: () => false,
                            );
                            if (terminal && _activeTriggerIndex != null) {
                              final idx = _activeTriggerIndex!;
                              _reVerificationScheduler?.markCompleted(idx);
                              _activeTriggerIndex = null;
                            }
                          });
                          return _reVerificationBloc!;
                        },
                      ),
                      // INFO : Need to add bloc of package Here
                      BlocProvider(
                        create: (context) {
                          final userId = context.loggedInUserUuid;

                          final isar = context.read<Isar>();
                          final bloc = SyncBloc(
                            isar: isar,
                            syncService: SyncService(),
                          );

                          if (!bloc.isClosed) {
                            bloc.add(SyncRefreshEvent(userId));
                          }
                          /* Every time when the user changes the screen
     this will refresh the data of sync count */
                          isar.opLogs
                              .filter()
                              .createdByEqualTo(userId)
                              .syncedUpEqualTo(false)
                              .watch()
                              .listen(
                            (event) {
                              if (!bloc.isClosed) {
                                triggerSyncRefreshEvent(bloc, userId, event);
                              }
                            },
                          );

                          isar.opLogs
                              .filter()
                              .createdByEqualTo(userId)
                              .syncedUpEqualTo(true)
                              .syncedDownEqualTo(false)
                              .watch()
                              .listen(
                            (event) {
                              if (!bloc.isClosed) {
                                triggerSyncRefreshEvent(bloc, userId, event);
                              }
                            },
                          );

                          return bloc;
                        },
                      ),
                      BlocProvider(
                        create: (_) => LocationBloc(location: Location())
                          ..add(const LoadLocationEvent()),
                      ),
                      BlocProvider(
                        create: (ctx) => BeneficiaryDownSyncBloc(
                          bandwidthCheckRepository: BandwidthCheckRepository(
                            DioClient().dio,
                            bandwidthPath:
                                envConfig.variables.checkBandwidthApiPath,
                          ),
                          individualLocalRepository: ctx.read<
                              LocalRepository<IndividualModel,
                                  IndividualSearchModel>>(),
                          downSyncRemoteRepository: ctx.read<
                              RemoteRepository<DownsyncModel,
                                  DownsyncSearchModel>>(),
                          downSyncLocalRepository: ctx.read<
                              LocalRepository<DownsyncModel,
                                  DownsyncSearchModel>>(),
                          householdLocalRepository: ctx.read<
                              LocalRepository<HouseholdModel,
                                  HouseholdSearchModel>>(),
                          householdMemberLocalRepository: ctx.read<
                              LocalRepository<HouseholdMemberModel,
                                  HouseholdMemberSearchModel>>(),
                          projectBeneficiaryLocalRepository: ctx.read<
                              LocalRepository<ProjectBeneficiaryModel,
                                  ProjectBeneficiarySearchModel>>(),
                          taskLocalRepository: ctx.read<
                              LocalRepository<TaskModel, TaskSearchModel>>(),
                          sideEffectLocalRepository: ctx.read<
                              LocalRepository<SideEffectModel,
                                  SideEffectSearchModel>>(),
                          referralLocalRepository: ctx.read<
                              LocalRepository<ReferralModel,
                                  ReferralSearchModel>>(),
                          hfReferralLocalRepository: ctx.read<
                              LocalRepository<HFReferralModel,
                                  HFReferralSearchModel>>(),
                          serviceLocalRepository: ctx.read<
                              LocalRepository<ServiceModel,
                                  ServiceSearchModel>>(),
                        ),
                      ),
                      BlocProvider(
                        create: (ctx) => StockDownSyncBloc(
                          context: context,
                          localSecureStore: LocalSecureStore.instance,
                          bandwidthCheckRepository: BandwidthCheckRepository(
                            DioClient().dio,
                            bandwidthPath:
                                envConfig.variables.checkBandwidthApiPath,
                          ),
                          projectFacilityLocalRepository: ctx.read<
                              LocalRepository<ProjectFacilityModel,
                                  ProjectFacilitySearchModel>>(),
                          facilityLocalRepository: ctx.read<
                              LocalRepository<FacilityModel,
                                  FacilitySearchModel>>(),
                          stockRemoteRepository: ctx.read<
                              RemoteRepository<StockModel, StockSearchModel>>(),
                          stockLocalRepository: ctx.read<
                              LocalRepository<StockModel, StockSearchModel>>(),
                          projectResourceLocalRepository: ctx.read<
                              LocalRepository<ProjectResourceModel,
                                  ProjectResourceSearchModel>>(),
                          downSyncLocalRepository: ctx.read<
                              LocalRepository<DownsyncModel,
                                  DownsyncSearchModel>>(),
                          userActionRemoteRepository:
                              ctx.read<UserActionRemoteRepository>(),
                          userActionLocalRepository:
                              ctx.read<UserActionLocalRepository>(),
                        ),
                      ),
                      BlocProvider(
                        create: (ctx) => HFReferralDownSyncBloc(
                          bandwidthCheckRepository: BandwidthCheckRepository(
                            DioClient().dio,
                            bandwidthPath:
                                envConfig.variables.checkBandwidthApiPath,
                          ),
                          hfReferralLocalRepository: ctx.read<
                              LocalRepository<HFReferralModel,
                                  HFReferralSearchModel>>(),
                          hfReferralRemoteRepository: ctx.read<
                              RemoteRepository<HFReferralModel,
                                  HFReferralSearchModel>>(),
                          downSyncLocalRepository: ctx.read<
                              LocalRepository<DownsyncModel,
                                  DownsyncSearchModel>>(),
                          projectFacilityLocalRepository: ctx.read<
                              LocalRepository<ProjectFacilityModel,
                                  ProjectFacilitySearchModel>>(),
                        ),
                      ),
                      BlocProvider(
                        create: (_) => ServiceBloc(
                          const ServiceEmptyState(),
                          serviceDataRepository: context
                              .repository<ServiceModel, ServiceSearchModel>(),
                        ),
                      ),
                      BlocProvider(
                        create: (_) => FormsBloc(),
                      ),
                    ],
                    child: MultiBlocListener(
                      listeners: [
                        BlocListener<PushNotificationBloc,
                            PushNotificationState>(
                          listener: (context, state) {
                            if (state is PushNotificationTappedState) {
                              final notificationData =
                                  NotificationData.fromMap(state.data);

                              NotificationHandlerFactory.getHandler(
                                      notificationData.notificationType)
                                  ?.handle(context, notificationData.payload);
                            }
                          },
                        ),
                        // When MDMS finishes loading after the re-verification
                        // scheduler has already started with default config,
                        // re-evaluate the FaceAuthConfig and restart the
                        // scheduler if MDMS values differ.
                        BlocListener<AppInitializationBloc,
                            AppInitializationState>(
                          // Was `prev is! AppInitialized && curr is AppInitialized`
                          // which only fires on the transition. If MDMS was
                          // already initialized before this widget mounted, the
                          // transition never happens and the scheduler stays on
                          // default config (e.g. endHour=18). React to every
                          // AppInitialized emit; _restartSchedulerWithConfig is
                          // a no-op when the merged config equals the current.
                          listenWhen: (prev, curr) => curr is AppInitialized,
                          listener: (context, state) async {
                            if (state is! AppInitialized) return;
                            if (_reVerificationScheduler == null) return;
                            final mdmsFaceConfig =
                                state.appConfiguration.faceAuthMdmsConfig;
                            if (mdmsFaceConfig == null) return;
                            final merged = FaceAuthConfig(
                              startHour: mdmsFaceConfig.startHour ??
                                  _faceAuthConfig.startHour,
                              endHour: mdmsFaceConfig.endHour ??
                                  _faceAuthConfig.endHour,
                              promptCount: mdmsFaceConfig.promptCount ??
                                  _faceAuthConfig.promptCount,
                              minGapMinutes: mdmsFaceConfig.minGapMinutes ??
                                  _faceAuthConfig.minGapMinutes,
                              countdownDuration: Duration(
                                  minutes: mdmsFaceConfig
                                          .countdownDurationMinutes ??
                                      _faceAuthConfig.countdownDuration
                                          .inMinutes),
                              maxFaceAttempts: mdmsFaceConfig.maxFaceAttempts ??
                                  _faceAuthConfig.maxFaceAttempts,
                              faceMatchThreshold:
                                  mdmsFaceConfig.faceMatchThreshold ??
                                      _faceAuthConfig.faceMatchThreshold,
                            );
                            final changed = merged.startHour !=
                                    _faceAuthConfig.startHour ||
                                merged.endHour != _faceAuthConfig.endHour ||
                                merged.promptCount !=
                                    _faceAuthConfig.promptCount ||
                                merged.minGapMinutes !=
                                    _faceAuthConfig.minGapMinutes ||
                                merged.countdownDuration !=
                                    _faceAuthConfig.countdownDuration;
                            if (changed) {
                              debugPrint(
                                'AuthenticatedPage: MDMS loaded after scheduler '
                                'start — restarting with MDMS config '
                                '(minGapMinutes ${_faceAuthConfig.minGapMinutes} '
                                '→ ${merged.minGapMinutes})',
                              );
                              _restartSchedulerWithConfig(merged);
                            }
                          },
                        ),
                        BlocListener<HFReferralDownSyncBloc,
                            HFReferralDownSyncState>(
                          listener: (context, hfDownSyncState) {
                            final localizations = AppLocalizations.of(context);
                            final appConfiguration = (context
                                    .read<AppInitializationBloc>()
                                    .state as AppInitialized)
                                .appConfiguration;
                            hfDownSyncState.maybeWhen(
                              orElse: () {},
                              loading: () {
                                DigitSyncDialog.show(
                                  context,
                                  type: DialogType.inProgress,
                                  label: localizations.translate(
                                    i18.beneficiaryDetails
                                        .dataDownloadInProgress,
                                  ),
                                  barrierDismissible: false,
                                );
                              },
                              dataFound: (newCount, serverTotalCount) {
                                Navigator.of(context, rootNavigator: true)
                                    .popUntil((route) => route is! PopupRoute);
                                showCustomPopup(
                                  barrierDismissible: false,
                                  context: context,
                                  builder: (ctx) => Popup(
                                    title: localizations.translate(
                                      newCount > 0
                                          ? i18.beneficiaryDetails.dataFound
                                          : i18.beneficiaryDetails.noDataFound,
                                    ),
                                    titleIcon: Icon(
                                      Icons.info_outline_rounded,
                                      color: Theme.of(context)
                                          .colorTheme
                                          .text
                                          .primary,
                                    ),
                                    description: localizations.translate(
                                      newCount > 0
                                          ? i18.beneficiaryDetails
                                              .dataFoundContent
                                          : i18.beneficiaryDetails
                                              .noDataFoundContent,
                                    ),
                                    actions: [
                                      DigitButton(
                                        label: localizations.translate(
                                          newCount > 0
                                              ? i18.common.coreCommonDownload
                                              : i18.common.coreCommonGoback,
                                        ),
                                        onPressed: () {
                                          if (newCount > 0) {
                                            context
                                                .read<HFReferralDownSyncBloc>()
                                                .add(
                                                  HFReferralDownSyncDownloadEvent(
                                                    projectId:
                                                        context.projectId,
                                                    appConfiguration: [
                                                      appConfiguration
                                                    ],
                                                    totalCount: newCount,
                                                    serverTotalCount:
                                                        serverTotalCount,
                                                  ),
                                                );
                                          } else {
                                            Navigator.of(context,
                                                    rootNavigator: true)
                                                .pop();
                                            context.router
                                                .replaceAll([HomeRoute()]);
                                          }
                                        },
                                        type: DigitButtonType.primary,
                                        size: DigitButtonSize.medium,
                                      ),
                                      if (newCount > 0)
                                        DigitButton(
                                          label: localizations.translate(
                                            i18.beneficiaryDetails
                                                .proceedWithoutDownloading,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context,
                                                    rootNavigator: true)
                                                .pop();
                                            context.router
                                                .replaceAll([HomeRoute()]);
                                          },
                                          type: DigitButtonType.secondary,
                                          size: DigitButtonSize.medium,
                                        ),
                                    ],
                                  ),
                                );
                              },
                              inProgress: (syncedCount, totalCount) {
                                final progressData = HFReferralProgressData(
                                  progress: totalCount == 0
                                      ? 0
                                      : (syncedCount / totalCount)
                                          .clamp(0.0, 1.0),
                                  syncedCount: syncedCount,
                                  totalCount: totalCount,
                                );
                                if (syncedCount < 1) {
                                  if (_hfReferralProgress.isClosed) {
                                    _hfReferralProgress = StreamController<
                                        HFReferralProgressData>.broadcast();
                                  }
                                  showHFReferralProgressDialog(
                                    context,
                                    title: localizations.translate(
                                      i18.beneficiaryDetails
                                          .dataDownloadInProgress,
                                    ),
                                    progressController: _hfReferralProgress,
                                    initialData: progressData,
                                  );
                                }
                                if (!_hfReferralProgress.isClosed) {
                                  _hfReferralProgress.add(progressData);
                                }
                              },
                              success: (syncedCount, totalCount) {
                                Navigator.of(context, rootNavigator: true)
                                    .popUntil((route) => route is! PopupRoute);
                                DigitSyncDialog.show(
                                  context,
                                  type: DialogType.complete,
                                  label: localizations.translate(
                                    i18.beneficiaryDetails
                                        .referralDownloadCompleted,
                                  ),
                                  primaryAction: DigitDialogActions(
                                    label: localizations.translate(
                                      i18.acknowledgementSuccess.goToHome,
                                    ),
                                    action: (ctx) {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      context.router.replaceAll([HomeRoute()]);
                                    },
                                  ),
                                );
                              },
                              failed: () {
                                Navigator.of(context, rootNavigator: true)
                                    .popUntil((route) => route is! PopupRoute);
                                DigitSyncDialog.show(
                                  context,
                                  type: DialogType.failed,
                                  label: localizations.translate(
                                    i18.common.coreCommonDownloadFailed,
                                  ),
                                  primaryAction: DigitDialogActions(
                                    label: localizations.translate(
                                      i18.syncDialog.retryButtonLabel,
                                    ),
                                    action: (ctx) {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      context
                                          .read<HFReferralDownSyncBloc>()
                                          .add(
                                            HFReferralDownSyncStartEvent(
                                              projectId: context.projectId,
                                              appConfiguration: [
                                                appConfiguration
                                              ],
                                            ),
                                          );
                                    },
                                  ),
                                  secondaryAction: DigitDialogActions(
                                    label: localizations.translate(
                                      i18.beneficiaryDetails
                                          .proceedWithoutDownloading,
                                    ),
                                    action: (ctx) {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      context.router.replaceAll([HomeRoute()]);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                      child: ErrorBoundary(builder: (context, error) {
                        if (error == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _checkFaceEnrollment();
                            _prefetchCoWorkerEmbeddings(context);
                            _retryPendingWorkerRegistrySync();
                          });
                        }
                        return error != null
                            ? const ErrorScreen()
                            : ReVerificationListener(
                              child: Column(
                              children: [
                                const _ReVerificationCountdownBanner(),
                                Expanded(child: AutoRouter(
                              navigatorObservers: () => [
                                AuthenticatedRouteObserver(
                                  onNavigated: () {
                                    bool shouldShowDrawer;
                                    switch (context.router.topRoute.name) {
                                      case ProjectSelectionRoute.name:
                                      case BoundarySelectionRoute.name:
                                      case PermissionsRoute.name:
                                      case FaceGateRoute.name:
                                        shouldShowDrawer = false;
                                        break;
                                      default:
                                        shouldShowDrawer = true;
                                    }

                                    _drawerVisibilityController
                                        .add(shouldShowDrawer);
                                  },
                                ),
                              ],
                            )),
                              ],
                            ),
                      );
                      }),
                    ),
                  ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void triggerSyncRefreshEvent(
      SyncBloc bloc, String userId, List<OpLog> event) {
    bloc.add(
      SyncRefreshEvent(
        userId,
        SyncServiceSingleton().entityMapper!.getSyncCount(event),
      ),
    );
  }

  Widget drawerWidget(BuildContext context) {
    final appInitializationBloc = context.read<AppInitializationBloc>();
    final appConfig =
        (appInitializationBloc.state as AppInitialized).appConfiguration;
    final languages = appConfig.languages;
    final localizationModulesList = appConfig.backendInterface;
    final authBloc = context.read<AuthBloc>();
    bool isDistributor = authBloc.state != const AuthState.unauthenticated()
        ? context.loggedInUserRoles
            .where(
              (role) => role.code == RolesType.distributor.toValue(),
            )
            .toList()
            .isNotEmpty
        : false;

    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return BlocListener<LocalizationBloc, LocalizationState>(
        listener: (context, state) {
          if (state.loading == false) {
            Navigator.of(context, rootNavigator: true).pop();
          } else {
            DigitLoaders.overlayLoader(context: context);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: SideBar(
              profile: state.maybeMap(
                authenticated: (value) {
                  String qrData =
                      "${value.userModel.userName}||${context.loggedInUserUuid}";
                  return ProfileWidget(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.router.push(UserQRDetailsRoute());
                      },
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 150.0,
                      ),
                    ),
                    title: value.userModel.name.toString(),
                    description: value.userModel.mobileNumber.toString(),
                  );
                },
                orElse: () => null,
              ),
              sidebarItems: [
                SidebarItem(
                  title: AppLocalizations.of(context).translate(
                    i18.common.coreCommonHome,
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    context.router.replaceAll([HomeRoute()]);
                  },
                  icon: Icons.home,
                ),
                if (isDistributor) ...[
                  SidebarItem(
                    title: AppLocalizations.of(context).translate(
                      i18.common.coreCommonViewDownloadedData,
                    ),
                    icon: Icons.download,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      context.router.push(const BeneficiariesReportRoute());
                    },
                  ),
                  SidebarItem(
                    title: AppLocalizations.of(context).translate(
                      i18.nonMobileUser.nonMobileUserLabel,
                    ),
                    icon: Icons.people_outline,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      context.router.navigate(const NonMobileUserListRoute());
                    },
                  ),
                ],
              ],
              logOutDigitButtonLabel: AppLocalizations.of(context)
                  .translate(i18.common.coreCommonLogout),
              onLogOut: () async {
                final isConnected = await getIsConnected();
                if (context.mounted) {
                  if (isConnected) {
                    await showCustomPopup(
                      context: context,
                      builder: (ctx) => Popup(
                        title: AppLocalizations.of(context).translate(
                          i18.common.coreCommonWarning,
                        ),
                        description: AppLocalizations.of(context).translate(
                          i18.common.logOutWarningMsg,
                        ),
                        onOutsideTap: () {
                          Navigator.of(ctx).pop();
                        },
                        type: PopUpType.simple,
                        actions: [
                          DigitButton(
                              label: AppLocalizations.of(context).translate(
                                i18.common.coreCommonOk,
                              ),
                              onPressed: () async {
                                final isar = context.read<Isar>();
                                final serviceRegistry = await isar
                                    .serviceRegistrys
                                    .where()
                                    .findAll();
                                final apiEndPoint =
                                    Constants.getNotificationEndPoint(
                                  serviceRegistry: serviceRegistry,
                                  service: 'NOTIFICATION',
                                  action: ApiOperation.unRegister.toValue(),
                                  entityName: 'NotificationToken',
                                );

                                if (context.mounted) {
                                  context.read<PushNotificationBloc>().add(
                                        PushNotificationEvent.logout(
                                          apiEndPoint: apiEndPoint,
                                        ),
                                      );
                                  context
                                      .read<BoundaryBloc>()
                                      .add(const BoundaryResetEvent());
                                  context.read<LocalizationBloc>().add(
                                        LocalizationEvent.onLoadLocalization(
                                          module: Constants
                                              .homeLocalizationModules
                                              .join(','),
                                          tenantId:
                                              envConfig.variables.tenantId,
                                          locale: AppSharedPreferences()
                                                  .getSelectedLocale ??
                                              '',
                                          path: Constants.localizationApiPath,
                                        ),
                                      );
                                  context
                                      .read<AuthBloc>()
                                      .add(const AuthLogoutEvent());
                                }
                              },
                              type: DigitButtonType.secondary,
                              size: DigitButtonSize.large),
                          DigitButton(
                              label: AppLocalizations.of(context).translate(
                                i18.common.coreCommonNo,
                              ),
                              onPressed: () {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(true);
                              },
                              type: DigitButtonType.primary,
                              size: DigitButtonSize.large)
                        ],
                      ),
                    );
                  } else {
                    Toast.showToast(
                      context,
                      message: AppLocalizations.of(context).translate(
                        i18.login.noInternetError,
                      ),
                      type: ToastType.error,
                    );
                  }
                }
              },
              footer: PoweredByDigit(
                version: Constants().version,
              ),
            ),
          ),
        ),
      );
    });
  }

  List<SidebarItem>? buildLanguage(
      BackendInterface localizationModulesList,
      List<Languages>? languages,
      BuildContext context,
      AppConfiguration appConfig) {
    final state = context.read<AppInitializationBloc>().state as AppInitialized;
    return languages
        ?.map((e) => SidebarItem(
              title: e.label,
              onPressed: () async {
                DigitLoaders.overlayLoader(context: context);

                int index = languages.indexWhere(
                  (ele) => ele.value.toString() == e.value.toString(),
                );

                /// TODO: NEED TO CHECK HOW CAN WE UPDATE THE LOCALIZATION BASED ON THE FLOW
                // String? dynamicModule;
                // final isInRegistrationFlow = context.router.current.name
                //     .contains(RegistrationDeliveryWrapperRoute.name);
                //
                // if (isInRegistrationFlow) {
                //   final prefs = await SharedPreferences.getInstance();
                //   final schemaJsonRaw = prefs.getString('app_config_schemas');
                //
                //   if (schemaJsonRaw != null) {
                //     final allSchemas =
                //         json.decode(schemaJsonRaw) as Map<String, dynamic>;
                //     final projectId = context.selectedProject.referenceID;
                //
                //     // Initialize empty list to collect modules
                //     final List<String> modules = [];
                //
                //     // Handle registrationflow
                //     final registrationSchemaEntry =
                //         allSchemas['REGISTRATIONFLOW'] as Map<String, dynamic>?;
                //     final registrationSchemaData =
                //         registrationSchemaEntry?['data'];
                //     final registrationFlowName = registrationSchemaData?['name']
                //         ?.toString()
                //         .toLowerCase();
                //     if (registrationFlowName != null && projectId != null) {
                //       modules.add('hcm-$registrationFlowName-$projectId');
                //     }
                //
                //     // Handle deliveryflow
                //     final deliverySchemaEntry =
                //         allSchemas['DELIVERYFLOW'] as Map<String, dynamic>?;
                //     final deliverySchemaData = deliverySchemaEntry?['data'];
                //     final deliveryFlowName =
                //         deliverySchemaData?['name']?.toString().toLowerCase();
                //     if (deliveryFlowName != null && projectId != null) {
                //       modules.add('hcm-$deliveryFlowName-$projectId');
                //     }
                //
                //     // Combine into a single string
                //     dynamicModule = modules.join(',');
                //   }
                // }
                //
                // final staticModules = localizationModulesList.interfaces
                //     .where((element) =>
                //         element.type == Modules.localizationModule &&
                //         Constants.homeLocalizationModules
                //             .contains(element.name.toString()))
                //     .map((e) => e.name.toString())
                //     .followedBy([
                //   'hcm-boundary-${envConfig.variables.hierarchyType}'
                // ]).join(',');
                //
                // final combinedModules = dynamicModule != null
                //     ? '$dynamicModule,$staticModules'
                //     : staticModules;
                //
                // context
                //     .read<LocalizationBloc>()
                //     .add(LocalizationEvent.onLoadLocalization(
                //       module: combinedModules,
                //       tenantId: appConfig.tenantId ?? "default",
                //       locale: e.value.toString(),
                //       path: Constants.localizationApiPath,
                //     ));

                context.read<LocalizationBloc>().add(
                      OnUpdateLocalizationIndexEvent(
                        index: index,
                        code: e.value.toString(),
                      ),
                    );
              },
              initiallySelected: getSelectedLanguage(
                  state,
                  languages.indexWhere(
                    (ele) => ele.value.toString() == e.value.toString(),
                  )),
            ))
        .toList();
  }
}

class _ReVerificationCountdownBanner extends StatelessWidget {
  const _ReVerificationCountdownBanner();

  @override
  Widget build(BuildContext context) {
    if (context.isTeamSupervisorRole) return const SizedBox.shrink();

    final currentRoute = context.router.topRoute.name;
    final isOnFaceGate = currentRoute == FaceGateRoute.name;

    return BlocBuilder<ReVerificationBloc, ReVerificationState>(
      builder: (context, state) {
        final isPrompted = state is ReVerificationPromptedState && !isOnFaceGate;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(animation),
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: isPrompted
              ? _CountdownContent(
                  key: const ValueKey('countdown_active'),
                  remainingSeconds:
                      (state as ReVerificationPromptedState).remainingSeconds,
                  totalSeconds: context
                      .read<ReVerificationBloc>()
                      .config
                      .countdownDuration
                      .inSeconds,
                  iteration: (state as ReVerificationPromptedState).iteration,
                  maxIterations:
                      (state as ReVerificationPromptedState).maxIterations,
                )
              : const SizedBox.shrink(key: ValueKey('countdown_hidden')),
        );
      },
    );
  }
}

class _CountdownContent extends StatefulWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final int? iteration;
  final int? maxIterations;

  const _CountdownContent({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.iteration,
    this.maxIterations,
  });

  @override
  State<_CountdownContent> createState() => _CountdownContentState();
}

class _CountdownContentState extends State<_CountdownContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    coWorkerPendingNotifier.addListener(_onCoWorkerPendingChanged);
  }

  void _onCoWorkerPendingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    coWorkerPendingNotifier.removeListener(_onCoWorkerPendingChanged);
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCountdown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorTheme;
    final progress = widget.remainingSeconds / widget.totalSeconds;
    final isUrgent = widget.remainingSeconds < 60;
    final accentColor = colorTheme.primary.primary1;
    final urgentColor = const Color(0xFFE53935);

    final barColor = isUrgent ? urgentColor : accentColor;

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorTheme.primary.primary2,
            colorTheme.primary.primary2.withOpacity(0.95),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: barColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.face_rounded,
                        size: 16,
                        color: barColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face Verification Required',
                          style: TextStyle(
                            color: colorTheme.paper.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isUrgent
                              ? 'Hurry! Time running out'
                              : coWorkerPendingNotifier.value
                                  ? 'Co-worker verification pending'
                                  : 'System user must verify face first',
                          style: TextStyle(
                            color: colorTheme.paper.primary.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: barColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 13, color: barColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatCountdown(widget.remainingSeconds),
                          style: TextStyle(
                            color: barColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.iteration != null && widget.maxIterations != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorTheme.paper.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorTheme.paper.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${widget.iteration}/${widget.maxIterations}',
                        style: TextStyle(
                          color: colorTheme.paper.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _processing
                        ? null
                        : () async {
                            if (reVerificationInProgressNotifier.value) return;
                            setState(() => _processing = true);
                            reVerificationInProgressNotifier.value = true;
                            try {
                              if (coWorkerPendingNotifier.value) {
                                await verifyCoWorkersPending(context);
                                return;
                              }
                              final result =
                                  await showFaceVerificationDialog(context);
                              if (!context.mounted) return;
                              if (result.passed) {
                                await logAndCompleteReVerification(
                                    context, result);
                              }
                            } finally {
                              reVerificationInProgressNotifier.value = false;
                              if (mounted) setState(() => _processing = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _processing
                            ? accentColor.withOpacity(0.6)
                            : accentColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _processing
                            ? null
                            : [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: _processing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorTheme.paper.primary,
                              ),
                            )
                          : Text(
                              'VERIFY',
                              style: TextStyle(
                                color: colorTheme.paper.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: progress, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.linear,
            builder: (context, value, _) {
              return Container(
                height: 3,
                width: double.infinity,
                color: Colors.black.withOpacity(0.2),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: isUrgent
                            ? [urgentColor.withOpacity(0.7), urgentColor]
                            : [accentColor.withOpacity(0.7), accentColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
