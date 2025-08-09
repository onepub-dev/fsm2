import '../definitions/co_region_definition.dart';
import '../types.dart';
import 'state_builder.dart';

class CoRegionBuilder<S extends State> extends StateBuilder<S> {
  // [coRegion] is a [StateDefinition]
  // ignore: matching_super_parameters
  CoRegionBuilder(super.parent, CoRegionDefinition<S> super.coRegion);

  // void onJoin<JS extends State>(BuildJoin<JS> buildJoin,
  //{Function(JS, Event) condition}) {
  //   final builder = JoinBuilder<JS>(_stateDefinition);
  //   buildJoin(builder);
  //   final definition = builder.build();

  //   var choice = JoinTransitionDefinition(_stateDefinition, definition);

  //   _stateDefinition.addTransition(choice);
  // }
}
