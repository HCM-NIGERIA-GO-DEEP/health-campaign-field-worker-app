import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/models/entities/user_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location/location.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:transit_post/blocs/transit_post.dart';
import 'package:transit_post/data/repositories/local/user_action.dart';
import 'package:transit_post/utils/extensions/extensions.dart';

@RoutePage()
class TransitPostWrapperPage extends StatelessWidget {
  const TransitPostWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              final loc = Location();
              final bloc = LocationBloc(location: loc)
                ..add(const LoadLocationEvent());
              bloc.stream.firstWhere((s) => s.hasPermissions).then((_) async {
                if (await loc.hasPermission() == PermissionStatus.granted) {
                  await loc.changeSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: 0,
                  );
                }
              }).catchError((_) {});
              return bloc;
            },
            lazy: false,
          ),
          BlocProvider(
            create: (_) {
              return TransitPostBloc(
                const TransitPostState(),
                userActionLocalRepository:
                    context.read<UserActionLocalRepository>(),
                userActionRemoteRepository:
                    context.repository<UserActionModel, UserActionSearchModel>(
                        context),
              );
            },
            lazy: false,
          ),
        ],
        child: const AutoRouter(),
      ),
    );
  }
}
