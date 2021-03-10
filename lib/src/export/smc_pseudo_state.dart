
import 'smc_state.dart';

class SMCPseudoState extends SMCState {
  SMCPseudoState(SMCState owner,
      {required String name, required SMCStateType type})
      : super(name: name, type: type, pageBreak: false) {
    super.parent = owner;
  }
}

class SMCInitialState extends SMCPseudoState {
  static const initial = 'initial';
  SMCInitialState(SMCState owner, Type stateType)
      : super(owner, name: stateType.toString(), type: SMCStateType.initial);

  @override
  String get name => ']${super.name}.$initial';
}

/// Will be represented as a UML2 fork 'bar' in the diagram
class SMCForkState extends SMCPseudoState {
  static const fork = 'fork';
  SMCForkState(SMCState owner, Type stateType)
      : super(owner, name: stateType.toString(), type: SMCStateType.fork);

  @override
  String get name => ']${super.name}.$fork';
}

/// Will be represented as a UML2 join 'bar' in the diagram
class SMCJoinState extends SMCPseudoState {
  static const join = 'join';
  SMCJoinState(SMCState owner, Type stateType)
      : super(owner, name: stateType.toString(), type: SMCStateType.join);

  @override
  String get name => ']${super.name}.$join';
}

class SMCTerminalState extends SMCPseudoState {
  static const finalState = 'final';

  SMCTerminalState(SMCState owner, Type type)
      : super(owner, name: type.toString(), type: SMCStateType.terminal);

  @override
  String get name => ']${super.name}.$finalState';
}
