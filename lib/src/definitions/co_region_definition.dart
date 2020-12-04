import '../definitions/state_definition.dart';
import '../types.dart';

class CoRegionDefinition<S extends State> extends StateDefinition<S> {
  CoRegionDefinition(Type stateType) : super(stateType);
}
