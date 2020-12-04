import 'graph.dart';
import 'definitions/state_definition.dart';
import 'types.dart';
import 'virtual_root.dart';

/// describes a path from a leaf state up to the root state.
class PartialStatePath {
  /// List of states from the leaf (stored as the first element in the array) to the root state.
  final List<StateDefinition> _path;

  PartialStatePath._internal() : _path = <StateDefinition>[];

  PartialStatePath() : this._internal();

  PartialStatePath.fromPath(this._path);

  StateDefinition<State> get leaf => _path.first;

  /// returns a unmodifiable list with the full path from the leaf to its root.
  List<StateDefinition> get path => List.unmodifiable(_path);

  bool get isNotEmpty => _path.isNotEmpty;

  bool isInState(Type state) {
    for (var stateDef in _path) {
      if (stateDef.stateType == state) return true;
    }
    return false;
  }

  /// Adds [stateDefinition] to the existing path
  /// as the oldest ancestor.
  void addAncestor(StateDefinition<State> stateDefinition) {
    _path.add(stateDefinition);
  }

  /// converts a [PartialStatePath] to a full [StatePath]
  StatePath fullPath(Graph graph) => StatePath.fromLeaf(graph, leaf.stateType);

  @override
  bool operator ==(covariant PartialStatePath other) {
    if (_path.isEmpty && other._path.isEmpty) return true;
    if (_path.length != other._path.length) return false;

    return leaf.stateType == other.leaf.stateType;
  }

  int _hashCode;
  @override
  int get hashCode {
    _hashCode ??= _path.fold(0, (hash, def) => hash += def.stateType.hashCode);
    return _hashCode;
  }
}

/// Identical to a [StatePath] but we use this class
/// when we don't guarentee that each path goes
/// all the way back to to the root.
///
/// This class should only be used to store
/// a path which starts from an active leaf.
class StatePath extends PartialStatePath {
  StatePath(List<StateDefinition> path)
      : super.fromPath(List.unmodifiable(path));

  /// Creates a [StatePath] from a leaf by trace
  /// up the graph to determine the complete list
  /// of ancestors to the root.
  StatePath.fromLeaf(Graph graph, Type leafState) {
    var ancestors = PartialStatePath();
    ancestors.addAncestor((graph.findStateDefinition(leafState)));
    var parent = graph.getParent(leafState);

    while (parent != VirtualRoot) {
      ancestors.addAncestor(graph.findStateDefinition(parent));
      parent = graph.getParent(parent);
    }

    ancestors.addAncestor(graph.virtualRoot);

    _path.addAll(ancestors._path);
  }
}
