import 'dart:developer';

import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

import 'watcher.mocks.dart';

void main() {
  test('initial event', () async {
    final watcher = MockWatcher();
    await createMachine(watcher);
  }, skip: false);
}

class TypingFormula implements State {}

class Typing implements State {}

// class Idle implements State {}

Future<StateMachine> createMachine(MockWatcher watcher) async {
  final machine = await StateMachine.create((g) => g
    ..initialState<Typing>()
    ..state<Typing>((b) => b
      ..onFork<OnValueChange>(
        (b) => b
          ..target<Point>()
          ..target<Autocomplete>(),
        condition: (e) => true, // Some logic to check if it is a formula
      )
      ..coregion<TypingFormula>((b) => b
        ..onJoin<OnValueChange, Typing>(
          condition: (e) => false, // Some logic to check if it is a formula
        )

        // Autocomplete state machine
        ..state<Autocomplete>((b) => b
          // Autocomplete events
          ..on<OnCandidateSelection, AutocompleteList>()
          ..on<OnFunctionSelection, AutocompleteDetails>()
          ..on<OnAutocompleteInvalidSelection, AutocompleteUnavailable>()
          // Autocomplete states
          ..state<AutocompleteList>((b) => b)
          ..state<AutocompleteDetails>((b) => b)
          ..state<AutocompleteUnavailable>((b) => b))
        // Point mode state-mahcine
        ..state<Point>((b) => b
          // Point mode events
          ..on<OnReferenceSelection, PointReference>()
          ..on<OnSlotSelection, PointSlot>()
          ..on<OnDisablePoint, PointDisabled>()
          ..on<OnPointInvalidSelection, PointUnavailable>()
          // Point mode states
          ..state<PointUnavailable>((b) => b)
          ..state<PointSlot>((b) => b)
          ..state<PointReference>((b) => b)
          ..state<PointDisabled>((b) => b))))
    ..onTransition((from, e, to) => log(
        '''Received Event $e in State ${from!.stateType} transitioning to State ${to!.stateType}''')));
  return machine;
}

class PointReference extends State {}

class PointUnavailable extends State {}

class OnPointInvalidSelection extends Event {}

class PointDisabled extends State {}

class OnDisablePoint extends Event {}

class PointSlot extends State {}

class OnSlotSelection extends Event {}

// class PointReferencene extends State {}

class OnReferenceSelection extends Event {}

class OnFunctionSelection extends Event {}

class OnAutocompleteInvalidSelection extends Event {}

class AutocompleteUnavailable extends State {}

class AutocompleteDetails extends State {}

class OnCandidateSelection extends Event {}

class AutocompleteList extends State {}

class Point extends State {}

class Autocomplete extends State {}

// class OnBlur extends Event {}

// class OnFocus extends Event {}

class OnValueChange implements Event {
  // part of testing
  // ignore: unreachable_from_main
  const OnValueChange({required this.isFormula});
  // part of testing
  // ignore: unreachable_from_main
  final bool isFormula;
}
