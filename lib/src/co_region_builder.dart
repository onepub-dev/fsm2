import 'package:fsm2/src/state_builder.dart';

import 'co_region_definition.dart';
import 'state_definition.dart';
import 'types.dart';

class CoRegionBuilder<S extends State> extends StateBuilder<S> {
  CoRegionBuilder(
      Type stateType, StateDefinition parent, CoRegionDefinition<S> coRegion)
      : super(stateType, parent, coRegion);

  // void onJoin<JS extends State>(BuildJoin<JS> buildJoin, {Function(JS, Event) condition}) {
  //   final builder = JoinBuilder<JS>(_stateDefinition);
  //   buildJoin(builder);
  //   final definition = builder.build();

  //   var choice = JoinTransitionDefinition(_stateDefinition, definition);

  //   _stateDefinition.addTransition(choice);
  // }
}
