typedef GuardCondition<E extends Event> = bool Function(E event);

class Event {}

class QueuedEvent<E extends Event> {
  QueuedEvent(this.event, this.condition);
  E event;
  // ignore: unreachable_from_main
  GuardCondition<E> condition;
}

class StateMachine {
  List<QueuedEvent> queued = <QueuedEvent>[];

  void addEvent<E extends Event>(E event,
          {required GuardCondition<E> condition}) =>
      queued.add(QueuedEvent<E>(event, condition));

  void dispatch() {
    for (final qe in queued) {
      final qed = qe as dynamic;

      // The queue is essentially untyped as it contain
      // a variety of events and as Typedef doesn't support
      // inheritance we have to resort to dynamic types otherwise
      // we get runtime errors.
      // ignore: avoid_dynamic_calls
      final c = qed.condition as dynamic;
      // ignore: avoid_dynamic_calls
      c.call(qe.event);
    }
  }
}

class OnBadAir extends Event {
  OnBadAir(this.quality);
  int quality;
}

void main() {
  StateMachine()
    ..addEvent(OnBadAir(11), condition: (e) => e.quality < 10)
    ..dispatch();
}
