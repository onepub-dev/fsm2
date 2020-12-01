# 0.9.2
co-regions implemented. 
diagramming now works.
moved back to released version of synchronized.
creating unit tests for exports.

# 0.9.1
Improvements to exportor for graphwiz.

# 0.9.0
Unit tests now working except for registration test which is just because the statemachine isn't defined correctly.
Added enum _ChildrenType as part of implemenation of co-states.
Added toaster oven example
spelling.
Added stream method which outputs a StateOfMind that indicates the full set of states the statemachine is in.
Added test for duplicate states.
Added DuplicateStateException and remove NestedStateException as duplicate states are never allowed.
Change to static so we could test the analyse and export functions.
added color coding to state boxes.
Added check that no state is in the path twice.
added pedantic.
dot export appers to be mostly working.
documented the analyse and export methods.
Improved documentation. renamed getTranstion to evaluateCondtion. Renamed Condition to GuardCondition. Renamed transition methods to be clearer and cleanup up problems with searching the tree for a transition. Added ability to export a fsm to a dot file and a general traverseTree method. Added an implicit TerminalState to help when generating diagrams. Added additional unit testes.

# 0.8.2
Corrected spelling.

# 0.8.1
documentation improvements.

# 0.8.0
First release after diverging from fsm package.
## 0.0.5
- Introduced stronger typing in builder methods.
- Added onEnter and onExits state listeners.

## 0.0.4
- Restructured code.
- Updated documentation.

## 0.0.3
- Updated example.

## 0.0.2
- Updated README.

## 0.0.1
- Initial version.
