import 'package:fsm2/src/virtual_root.dart';

import 'definitions/state_definition.dart';

import 'state_path.dart';

class StateOfMind {
  /// List of the active leaf states.
  /// For each active leaf we retain a [StatePath].
  ///
  /// For a simple nested state the list will just have
  /// a single leafPath.
  /// If we have any active coregions then we will have a list
  /// of leafPaths.
  final _leafPaths = <StatePath>[];

  bool isInState(Type state) {
    for (final statePath in _leafPaths) {
      if (statePath.isInState(state)) return true;
    }
    return false;
  }

  void _removePath(StatePath path) {
    StatePath? toBeRemoved;
    for (final statePath in _leafPaths) {
      if (statePath == path) toBeRemoved = statePath;
    }

    // assert(toBeRemoved != null);
    _leafPaths.remove(toBeRemoved);

    dedup();
  }

  void _addPath(StatePath path) {
    _leafPaths.add(path);

    dedup();
  }

  StatePath? pathForLeafState(Type leafState) {
    for (final path in _leafPaths) {
      if (path.leaf!.stateType == leafState) {
        return path;
      }
    }
    return null;
  }

  /// returns a StateDefinition for all active states
  List<StateDefinition?> activeLeafStates() {
    final defs = <StateDefinition?>[];

    for (final active in _leafPaths) {
      if (active.isNotEmpty) {
        defs.add(active.leaf);
      }
    }
    return defs;
  }

  @override
  String toString() {
    final details = StringBuffer();

    var firststate = true;
    for (final statePath in _leafPaths) {
      if (!firststate) {
        details.write('\n  and ');
      }
      firststate = false;
      var firstpart = true;
      for (final path in statePath.path) {
        if (!firstpart) {
          details.write('->');
        }
        firstpart = false;
        details.write(path.stateType.toString());
      }
    }
    return details.toString();
  }

  /// With co-regions we can have multiple states that collapse into a single state.
  /// This can result in duplicate paths so we need to reduce the duplicates to a single state.
  void dedup() {
    final deduped = _leafPaths.toSet().toList();
    if (deduped.length != _leafPaths.length) {
      _leafPaths.clear();
      _leafPaths.addAll(deduped);
    }
  }

  /// We don't need a discrete parent StatePath if the
  /// state of mind also contains a child of that parent.
  ///
  void stripRedundantParents() {
    final seen = <StatePath>{};
    final remove = <StatePath>{};

    /// sortest paths first as we need to see the parent paths first
    _leafPaths.sort((lhs, rhs) => lhs.path.length - rhs.path.length);

    for (final path in _leafPaths) {
      StatePath next = path;

      /// chain up the path so we can compare each 'parent' path
      /// to the list of parents we have [seen].
      while (next.leaf.stateType != VirtualRoot().runtimeType) {
        if (seen.contains(next)) {
          remove.add(next);
        }

        next = next.parent;
      }
      seen.add(path);
    }

    for (final path in remove) {
      _leafPaths.remove(path);
    }
  }
}

/// Used to hide internal implementation details.
///

void removePath(StateOfMind som, StatePath path) {
  som._removePath(path);
}

void addPath(StateOfMind som, StatePath path) {
  som._addPath(path);
}
