import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location/location.dart';
import 'package:survey_form/survey_form.dart';
import 'package:survey_form/utils/extensions/context_utility.dart';

@RoutePage()
class SurveyFormWrapperPage extends StatelessWidget {
  final bool isEditing;

  const SurveyFormWrapperPage({
    super.key,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    final serviceDefinition = context.repository<ServiceDefinitionModel,
        ServiceDefinitionSearchModel>(context);

    final service =
        context.repository<ServiceModel, ServiceSearchModel>(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ServiceDefinitionBloc(
            const ServiceDefinitionEmptyState(),
            serviceDefinitionDataRepository: serviceDefinition,
          )..add(const ServiceDefinitionFetchEvent()),
          lazy: false,
        ),
        BlocProvider(
          create: (_) => ServiceBloc(
            const ServiceEmptyState(),
            serviceDataRepository: service,
          ),
        ),
        BlocProvider(create: (_) {
          final loc = Location();
          final bloc = LocationBloc(location: loc);
          bloc.stream.firstWhere((s) => s.hasPermissions).then((_) async {
            if (await loc.hasPermission() == PermissionStatus.granted) {
              await loc.changeSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
              );
            }
          }).catchError((_) {});
          return bloc;
        })
      ],
      child: const AutoRouter(),
    );
  }
}
