import '../definitions/fork_definition.dart';
import '../types.dart';
import 'graph_builder.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class ForkBuilder<E extends Event> {
  ForkBuilder() : _forkDefinition = ForkDefinition<E>();
  final ForkDefinition<E> _forkDefinition;

  ForkDefinition<E> build() => _forkDefinition;

  void target<S extends State>() {
    _forkDefinition.addTarget(S);
  }
}
