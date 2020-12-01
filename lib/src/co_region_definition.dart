import 'package:fsm2/src/state_definition.dart';
import 'package:fsm2/src/types.dart';

class CoRegionDefinition<S extends State> extends StateDefinition<S> {
  CoRegionDefinition(Type stateType) : super(stateType);
}
