import 'graph_builder.dart';

import 'join_definition.dart';
import 'state_definition.dart';
import 'types.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class JoinBuilder<S extends State> {
  final JoinDefinition<S> _joinDefinition;

  JoinBuilder(StateDefinition stateDefinition) : _joinDefinition = JoinDefinition<S>(S);

  JoinDefinition build() => _joinDefinition;

  void on<E extends Event>() {
    _joinDefinition.addEvent(E);
  }
}
