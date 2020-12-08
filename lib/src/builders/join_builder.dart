import '../definitions/join_definition.dart';
import '../types.dart';
import 'graph_builder.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class JoinBuilder<S extends State> {
  final JoinDefinition<S> _joinDefinition;

  JoinBuilder() : _joinDefinition = JoinDefinition<S>(S);

  JoinDefinition build() => _joinDefinition;

  void on<E extends Event>() {
    _joinDefinition.addEvent(E);
  }
}
