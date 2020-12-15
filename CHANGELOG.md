# 0.14.0
Breaking change:
Now passing the Event to sideEffect.

Improvements in exports.
Create SMCStates for each pseudo states.
Added missing logic to stop a join triggering until all events received. 
Cleaned up the public api a little, hiding some internal methods.
Added logic in the exporter to handle transitions from states in two different branches on different pages.
Create _SCMStatePath to describe states as a path.
Fixed a bug where a coregion at the top level created its on virtualRoot rather than reusing the existing one.
increased the page height and move the page no to the bottom.

# 0.14.0
Breaking Changes

the 'sideEffect' lambda is now passed the event that caused the transition.

# 0.13.0
Fixed for #2. We now call onEnter for all initial states when the statemachine is first created.

# 0.12.0
Added test of expected output when exporting page break tests.
improved unit tests for page breaks.
partial move to nullsaftey packages.
Made watch option more robust in the face of rendering errors. Added Page No.s to svg output.
Improvements to state rendering for straddled states.
Fixed bugs with join and fork rendering. Removed duplicate psuedo transitions.
Added condition and sideEffect labels.


# 0.11.0
Major work on the creation of svgs. We now support adding page breaks to the statemachine to have the digram span multiple pages.
added lint package.

# 0.10.1
updated the readme.md

# 0.10.0
Added watcher which re-renders svg and displays it. repalced .gv with .smcat. Minor fixes to the engine.
work on statecat implementation.
Use correct example layout

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
