# 3.3.0
- upgraded to dart 3.3.0
- upgraded to new lint hard that has fields at the top of classes.
- upgraded dependencies fixed lints.
- removed try2.

# 3.2.1
- expose GraphBuilder as part of the public API.

# 3.2.0
- fix for #23 - double dispatch of events.

# 3.1.1
Fixed #18 - coregion resolves before all onJoin events are received (2nd time) when sideEffect resolves one state

Again thanks to panghy for this patch.

# 3.1.0
Upgraded to latest dcli 4.0
Merge PR  from panghy which fixes #17 and #18.

# 3.1.0-alpha.1
Upgraded to dcli 4.0

# 3.0.0
Upgraded to Dart 3.x
Breaking changes:
Deprecated waitUntilQuiescent and replaced it with [StateMachine.complete]
StateMachine will now set its initialState to the first [State] that is added
if [intialState] isn't called. Previously it would throw a late initialisation 
error.

isInState is new asynchronise as it needs to wait for all outstanding events to complete before it checks the state.
# 2.0.7
Merged backports to masters.

# 2.0.6
- Fixed broken link to documentation.

# 2.0.5
Updated packages.
Updated documentation and repository links in pubspec.yaml.


# 2.0.4
Fixes #7

# 2.0.3
Added missing initialisation for quality in unit tests.

# 2.0.3
Added missing guardconditions to fork and join. No unit tests as yet.

# 2.0.2

# 2.0.0
Migrated to nnbd.
Added option to force regeneration.
Converted to nnbd. Fixed #4.

# 1.0.1
Back ported changes from 2.0.0

# 1.0.0
First stable release of fsm2.

# 0.17.4
Upgraded to latest version of dcli.

# 0.17.3
moved dcli to the dev dependencies.

# 0.17.2
un ignored version.g.dart
releasd 0.17.1
Improvements to the documentation.
released 0.17
removed unused code.
Made sideEffects typesafe.
Added state colours for the export.
Exposed co_region_builder and state_builder as part of the api.

# 0.17.1
released 0.17
removed unused code.
Made sideEffects typesafe.
Added state colours for the export.
Exposed co_region_builder and state_builder as part of the api.

# 0.17.0
Changes to help fsm2_viewer implementation.

smcatfile now wraps an svg file. Provided default empty content for svg file if it doesn't exist.
added image to readme

# 0.16.1
Fixes
smcatfile now wraps and svg file. Provided default empty content for svg file if it doesn't exist.
added image to readme.

# 0.16.0
refactored code so that the ability to generate and watch for changes are now part of the public api so that fms2_viewer can use them.

# 0.15.0
Breaking changes:
The onEnter and onExit handlers now expect both a state and the original event.

Unit tests and fixes for onJoin. 
Also provide a better mapping mechanism when a transition definition generates multiple or zero transitions.

The  --watch option form fsm2 app now supports filenames with no extension when there is only a single page. 
This way you can launch fsm2 without having to consider wether the smcat is a single page or multiple pages.

# 0.14.0
Breaking change:
Now passing the Event to sideEffect.

Improvements in exports.
Create SMCStates for each pseudo states.
Added missing logic to stop a join triggering until all events received. 
Cleaned up the public api a little, hiding some internal methods.
Added logic in the exporter to handle transitions from states in two different branches on different pages.
Create _SCMStatePath to describe states as a path.
Fixed a bug where a coregion at the top level created its own virtualRoot rather than reusing the existing one.
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
