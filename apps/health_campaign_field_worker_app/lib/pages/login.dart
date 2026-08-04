import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/models/privacy_notice/privacy_notice_model.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/digit_loader.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../blocs/app_initialization/app_initialization.dart';
import '../blocs/auth/auth.dart';
import '../blocs/localization/app_localization.dart';
import '../blocs/localization/localization.dart';
import '../data/local_store/no_sql/schema/app_configuration.dart';
import '../data/local_store/no_sql/schema/service_registry.dart';
import '../router/app_router.dart';
import '../utils/constants.dart';
import '../utils/environment_config.dart';
import '../utils/i18_key_constants.dart' as i18;
import '../widgets/localized.dart';
import '../widgets/privacy_notice/privacy_notice.dart';

@RoutePage()
class LoginPage extends LocalizedStatefulWidget {
  const LoginPage({
    Key? key,
    super.appLocalizations,
  }) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends LocalizedState<LoginPage> {
  var passwordVisible = false;
  bool isPrivacyEnabled = false;
  bool _localizationReady = false;
  static const _userId = 'userId';
  static const _password = 'password';
  static const _debugUserId = 'USR-314109';
  static const _debugPassword = 'eGov@123';

  String? _pendingUserId;
  String? _pendingPassword;

  @override
  void initState() {
    super.initState();
  }

  void _checkOtherDeviceLogin(BuildContext context, String username) async {
    final authBloc = context.read<AuthBloc>();

    try {
      final isar = await Constants().isar;
      final serviceRegistry = await isar.serviceRegistrys.where().findAll();

      if (serviceRegistry.isEmpty) {
        // Fall back to regular login if service registry is empty
        authBloc.add(const AuthEvent.allow());
        return;
      }

      final apiEndPoint = Constants.getMultiLoginEndPoint(
        serviceRegistry: serviceRegistry,
        service: Constants.multiLoginService,
        entityName: Constants.multiLoginEntity,
        action: ApiOperation.validate.toValue(),
      );

      authBloc.add(
        AuthEvent.checkOtherDeviceLogin(
          username: username,
          apiEndPoint: apiEndPoint,
          tenantId: envConfig.variables.tenantId,
        ),
      );
    } catch (e) {
      // Fall back to regular login on error
      authBloc.add(const AuthEvent.allow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      appBar: AppBar(
        foregroundColor: theme.colorTheme.paper.primary,
        backgroundColor: theme.colorTheme.primary.primary2,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          state.maybeWhen(
            orElse: () {},
            loading: () {
              DigitLoaders.overlayLoader(context: context);
            },
            allow: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.read<AuthBloc>().add(
                    AuthLoginEvent(
                      userId: _pendingUserId as String,
                      password: _pendingPassword as String,
                      tenantId: envConfig.variables.tenantId,
                    ),
                  );
            },
            otherDevice: () {
              Navigator.of(context, rootNavigator: true).pop();
              _showMultiDeviceLoginPopUp(
                context,
                username: _pendingUserId as String,
                password: _pendingPassword as String,
              );
            },
            error: (message) {
              Navigator.of(context, rootNavigator: true).pop();
              Toast.showToast(
                context,
                message: message ??
                    localizations.translate(i18.login.unableToLoginText),
                type: ToastType.error,
              );
            },
            authenticated: (_, __, ___, ____, _____) {
              Navigator.of(context, rootNavigator: true)
                  .popUntil((route) => route is! PopupRoute);
            },
          );
        },
        child: BlocBuilder<LocalizationBloc, LocalizationState>(
          // Only rebuild for the initial localization load. Once the form is
          // shown, ignore later loading toggles (triggered by the login/home
          // localization fetch) so the ReactiveForm isn't recreated — which
          // reset the privacy checkbox / disabled Login and flashed the
          // screen (the login flicker).
          buildWhen: (previous, current) => !_localizationReady,
          builder: (context, localizationState) {
            // Show a loader until localization strings finish loading so the
            // login form never flashes raw translation keys.
            if (localizationState.loading) {
              return DigitLoaders.showFullPageLoader(context: context);
            }

            _localizationReady = true;

            return ScrollableContent(
              children: [
                ReactiveFormBuilder(
                  form: buildForm,
                  builder: (context, form, child) {
                    return DigitCard(
                      margin: const EdgeInsets.all(spacer2),
                      children: [
                        Text(
                          localizations.translate(
                            i18.login.labelText,
                          ),
                          style: textTheme.headingXl.copyWith(
                            color: theme.colorTheme.primary.primary2,
                          ),
                        ),
                        ReactiveWrapperField(
                          formControlName: _userId,
                          validationMessages: {
                            "required": (control) {
                              return localizations.translate(
                                '${i18.login.userIdPlaceholder}_IS_REQUIRED',
                              );
                            },
                          },
                          builder: (field) => LabeledField(
                            label: localizations.translate(
                              i18.login.userIdPlaceholder,
                            ),
                            capitalizedFirstLetter: false,
                            isRequired: true,
                            child: DigitTextFormInput(
                              keyboardType: TextInputType.text,
                              initialValue: form.control(_userId).value,
                              errorMessage: field.errorText,
                              onChange: (value) {
                                form.control(_userId).value = value;
                              },
                            ),
                          ),
                        ),
                        ReactiveWrapperField(
                          formControlName: _password,
                          validationMessages: {
                            "required": (control) {
                              return localizations.translate(
                                '${i18.login.passwordPlaceholder}_IS_REQUIRED',
                              );
                            },
                          },
                          builder: (field) => LabeledField(
                            label: localizations.translate(
                              i18.login.passwordPlaceholder,
                            ),
                            isRequired: true,
                            child: DigitPasswordFormInput(
                              initialValue: form.control(_password).value,
                              errorMessage: field.errorText,
                              onChange: (value) {
                                form.control(_password).value = value;
                              },
                              keyboardType: TextInputType.text,
                            ),
                          ),
                        ),
                        // Privacy policy consent: the user must open the notice
                        // (via the link) and tick the checkbox before the login
                        // button is enabled.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: spacer2),
                              child: DigitCheckbox(
                                value: isPrivacyEnabled,
                                onChanged: (val) {
                                  setState(() {
                                    isPrivacyEnabled = val;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: textTheme.bodyS.copyWith(
                                    color: theme.colorTheme.primary.primary2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${localizations.translate(i18.privacyPolicy.privacyNoticeText)} ',
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () async {
                                          // Reading the notice and tapping
                                          // "Proceed" auto-selects the consent
                                          // checkbox.
                                          final proceeded =
                                              await showPrivacyNotice(context);
                                          if (proceeded && mounted) {
                                            setState(() {
                                              isPrivacyEnabled = true;
                                            });
                                          }
                                        },
                                        child: Text(
                                          localizations.translate(
                                            "PRIVACY_NOTICE",
                                          ),
                                          style: textTheme.bodyS.copyWith(
                                            color: theme
                                                .colorTheme.primary.primary1,
                                            decoration:
                                                TextDecoration.underline,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        BlocBuilder<AppInitializationBloc,
                            AppInitializationState>(
                          builder: (context, state) {
                            return DigitButton(
                              label: localizations
                                  .translate(i18.login.actionLabel),
                              type: DigitButtonType.primary,
                              isDisabled: !isPrivacyEnabled,
                              onPressed: () {
                                if (!isPrivacyEnabled) {
                                  Toast.showToast(
                                    context,
                                    message: localizations.translate(
                                      i18.privacyPolicy
                                          .privacyPolicyValidationText,
                                    ),
                                    type: ToastType.error,
                                  );
                                  return;
                                }
                                form.markAllAsTouched();
                                if (!form.valid) return;

                                FocusManager.instance.primaryFocus?.unfocus();

                                _pendingUserId =
                                    (form.control(_userId).value as String)
                                        .trim();
                                _pendingPassword =
                                    (form.control(_password).value as String)
                                        .trim();

                                context.read<AuthBloc>().add(
                                      AuthLoginEvent(
                                        userId: _pendingUserId as String,
                                        password: _pendingPassword as String,
                                        tenantId: envConfig.variables.tenantId,
                                      ),
                                    );

                                // if (singleUserLogin) {
                                //   _checkOtherDeviceLogin(
                                //       context, _pendingUserId as String);
                                // } else {

                                // }
                              },
                              size: DigitButtonSize.large,
                              mainAxisSize: MainAxisSize.max,
                            );
                          },
                        ),
                        DigitButton(
                          label: localizations.translate(
                            i18.forgotPassword.actionLabel,
                          ),
                          capitalizeLetters: false,
                          mainAxisSize: MainAxisSize.max,
                          type: DigitButtonType.tertiary,
                          size: DigitButtonSize.medium,
                          onPressed: () => showCustomPopup(
                            context: context,
                            builder: (ctx) => Popup(
                              title: localizations.translate(
                                i18.forgotPassword.labelText,
                              ),
                              description: localizations.translate(
                                i18.forgotPassword.contentText,
                              ),
                              onOutsideTap: () {
                                Navigator.of(ctx).pop();
                              },
                              type: PopUpType.simple,
                              actions: [
                                DigitButton(
                                  label: localizations.translate(
                                    i18.forgotPassword.primaryActionLabel,
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    context.router.popUntilRoot();
                                  },
                                  type: DigitButtonType.primary,
                                  size: DigitButtonSize.large,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  FormGroup buildForm() => fb.group(<String, Object>{
        _userId: FormControl<String>(
          value: kDebugMode ? _debugUserId : null,
          validators: [Validators.required],
        ),
        _password: FormControl<String>(
          value: kDebugMode ? _debugPassword : null,
          validators: [Validators.required],
        ),
      });
}

// // convert to privacy notice model
PrivacyNoticeModel? convertToPrivacyPolicyModel(PrivacyPolicy? privacyPolicy) {
  return PrivacyNoticeModel(
    header: privacyPolicy?.header ?? '',
    module: privacyPolicy?.module ?? '',
    active: privacyPolicy?.active,
    contents: privacyPolicy?.contents
        ?.map((content) => ContentNoticeModel(
              header: content.header,
              descriptions: content.descriptions
                  ?.map((description) => DescriptionNoticeModel(
                        text: description.text,
                        type: description.type,
                        isBold: description.isBold,
                        subDescriptions: description.subDescriptions
                            ?.map((subDescription) => SubDescriptionNoticeModel(
                                  text: subDescription.text,
                                  type: subDescription.type,
                                  isBold: subDescription.isBold,
                                  isSpaceRequired:
                                      subDescription.isSpaceRequired,
                                ))
                            .toList(),
                      ))
                  .toList(),
            ))
        .toList(),
  );
}

void _showMultiDeviceLoginPopUp(
  BuildContext context, {
  required String username,
  required String password,
}) {
  showCustomPopup(
    context: context,
    builder: (ctx) => Popup(
      title: AppLocalizations.of(context)
          .translate(i18.login.switchMobileDialogTitle),
      titleIcon: Icon(Icons.error_outline, color: const Light().alertError),
      additionalWidgets: [
        Text(
          AppLocalizations.of(context)
              .translate(i18.login.switchMobileDialogContent),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
      ],
      actions: [
        DigitButton(
          label: AppLocalizations.of(context)
              .translate(i18.login.switchMobileDialogContine),
          onPressed: () {
            Navigator.of(ctx).pop(); // Close popup
            // Use the parent context to navigate
            context.router.replaceAll([
              DeviceChangeReasonRoute(
                username: username,
                password: password,
              ),
            ]);
          },
          type: DigitButtonType.primary,
          mainAxisSize: MainAxisSize.max,
          size: DigitButtonSize.large,
        ),
        DigitButton(
          label: AppLocalizations.of(context)
              .translate(i18.login.switchMobileDialogBack),
          prefixIcon: Icons.undo,
          onPressed: () {
            context.read<AuthBloc>().add(const AuthEvent.reset());
            Navigator.of(ctx).pop(); // Just close popup
          },
          type: DigitButtonType.secondary,
          mainAxisSize: MainAxisSize.max,
          size: DigitButtonSize.medium,
        ),
      ],
    ),
  );
}
