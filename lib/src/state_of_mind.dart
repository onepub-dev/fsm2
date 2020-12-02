import 'definitions/state_definition.dart';

import 'state_path.dart';

class StateOfMind {
  /// List of the active leaf states.
  /// For each active leaf we retain a [StatePath].
  ///
  /// For a simple nested state the list will just have
  /// a single leafPath.
  /// If we have any active [coregion]s then we will have a list
  /// of leafPaths.
  final _leafPaths = <StatePath>[];

  bool isInState(Type state) {
    for (var statePath in _leafPaths) {
      if (statePath.isInState(state)) return true;
    }
    return false;
  }

  void removePath(StatePath path) {
    StatePath toBeRemoved;
    for (var statePath in _leafPaths) {
      if (statePath == path) toBeRemoved = statePath;
    }

    assert(toBeRemoved != null);
    _leafPaths.remove(toBeRemoved);
  }

  void addPath(StatePath path) {
    _leafPaths.add(path);
  }

  StatePath pathForLeafState(Type leafState) {
    for (var path in _leafPaths) {
      if (path.leaf.stateType == leafState) {
        return path;
      }
    }
    return null;
  }

  /// returns a StateDefinition for all active states
  List<StateDefinition> activeLeafStates() {
    var defs = <StateDefinition>[];

    for (var active in _leafPaths) {
      defs.add(active.leaf);
    }
    return defs;
  }
}
