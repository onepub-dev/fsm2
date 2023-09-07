import 'package:stacktrace_impl/stacktrace_impl.dart';

import 'state_of_mind.dart';
import 'types.dart';

class Tracker {
  Tracker(this.stateOfMind, this.transitionedBy) {
    stackTrace = StackTraceImpl(skipFrames: 1);
  }
  StackTraceImpl? stackTrace;

  StateOfMind stateOfMind;
  Event transitionedBy;
}
