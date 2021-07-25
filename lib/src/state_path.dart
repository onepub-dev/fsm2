import 'definitions/state_definition.dart';
import 'exceptions.dart';
import 'graph.dart';
import 'types.dart';
import 'virtual_root.dart';

/// Identical to a [StatePath] but we use this class
/// when we don't guarentee that each path goes
/// all the way back to to the root.
///
/// This class should only be used to store
/// a path which starts from an active leaf.
class PartialStatePath {
  /// List of states from the leaf (stored as the first element in the array) to the root state.
  final List<StateDefinition?> _path;

  PartialStatePath() : this._internal();

  PartialStatePath._internal() : _path = <StateDefinition?>[];

  PartialStatePath.fromPath(this._path);

  StateDefinition<State>? get leaf => _path.first;

  /// returns a unmodifiable list with the full path from the leaf to its root.
  List<StateDefinition> get path => List.unmodifiable(_path);

  bool get isNotEmpty => _path.isNotEmpty;

  bool isInState(Type state) {
    for (final stateDef in _path) {
      if (stateDef!.stateType == state) return true;
    }
    return false;
  }

  /// Adds [stateDefinition] to the existing path
  /// as the oldest ancestor.
  void addAncestor(StateDefinition<State>? stateDefinition) {
    _path.add(stateDefinition);
  }

  /// converts a [PartialStatePath] to a full [StatePath]
  StatePath fullPath(Graph graph) => StatePath.fromLeaf(graph, leaf!.stateType);

  @override
  bool operator ==(covariant PartialStatePath other) {
    if (_path.isEmpty && other._path.isEmpty) return true;
    if (_path.length != other._path.length) return false;

    return leaf!.stateType == other.leaf!.stateType;
  }

  int? _hashCode;
  @override
  int get hashCode {
    // ignore: join_return_with_assignment
    _hashCode ??= _path.fold(0, (hash, def) {
      var _hash = hash!;
      return _hash += def!.stateType.hashCode;
    });

    return _hashCode!;
  }
}

/// describes a path from a leaf state up to the root state.
class StatePath extends PartialStatePath {
  StatePath(List<StateDefinition?> path)
      : super.fromPath(List.unmodifiable(path));

  /// Creates a [StatePath] from a leaf by tracing
  /// up the graph to determine the complete list
  /// of ancestors to the root.
  StatePath.fromLeaf(Graph graph, Type leafState) {
    final ancestors = PartialStatePath();
    final ancestor = graph.findStateDefinition(leafState);
    if (ancestor != null) {
      ancestors.addAncestor(ancestor);
    }
    var parent = graph.getParent(leafState);

    while (parent != VirtualRoot) {
      final ancestor = graph.findStateDefinition(parent);
      if (ancestor != null) {
        ancestors.addAncestor(ancestor);
      }
      parent = graph.getParent(parent);
    }

    ancestors.addAncestor(graph.virtualRoot);

    _path.addAll(ancestors._path);
  }

  StatePath get parent {
    if (_path.length == 1) {
      throw NoParentException('The StatePath $_path does not have a parent');
    }
    return StatePath(_path.sublist(1, _path.length));
  }
}
