import 'package:digit_data_model/data_model.dart';
import 'package:flutter/material.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/app_localization.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';


class SelectedProjectBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ProjectModel selectedProject,
  ) projectBuilder;

  const SelectedProjectBuilder({
    super.key,
    required this.projectBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return RegistrationDeliverySingleton().selectedProject != null
        ? projectBuilder(
            context,
            RegistrationDeliverySingleton().selectedProject!,
          )
        : Center(
            child: Text(
              RegistrationDeliveryLocalization.of(context)
                  .translate(i18.common.noProjectSelected),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
  }
}
