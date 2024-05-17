import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

void main() {
  late StateMachine fsm;

  // test for https://github.com/onepub-dev/fsm2/issues/23
  test('test no double dispatch', () async {
    fsm = await StateMachine.create(
        (g) => g
          ..initialState<Start>()
          ..state<Start>((b) => b
            ..on<TestEvent, Loop>()
            ..state<StartA>((b) => b)
            ..state<Loop>((b) => b
              ..onEnter((s, e) async {
                fsm.applyEvent(TestEvent2());
                // this delay ensure that the dispatch for TestEvent2 would
                // fire which before the fix was applied would re-apply
                // TestEvent which is wrong.
                await Future.delayed(
                    const Duration(milliseconds: 100), () => true);
              })
              ..on<TestEvent2, Loop>())),
        production: true)
      // trigger the transition from StartA to Loop (and the onEnter for Loop).
      ..applyEvent(TestEvent());

    await fsm.complete;
  });
}

class Start extends State {}

class StartA extends State {}

class Loop extends State {}

class TestEvent extends Event {}

class TestEvent2 extends Event {}
