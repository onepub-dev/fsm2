import 'smc_state.dart';

class SMCPseudoState extends SMCState {
  SMCPseudoState({
    required SMCState super.parent,
    required super.name,
    required super.type,
  }) : super.pseudo(pageBreak: false);
}

class SMCInitialState extends SMCPseudoState {
  SMCInitialState(SMCState parent, Type stateType)
      : super(
          parent: parent,
          name: stateType.toString(),
          type: SMCStateType.initial,
        );
  static const initial = 'initial';

  @override
  String get name => ']${super.name}.$initial';
}

/// Will be represented as a UML2 fork 'bar' in the diagram
class SMCForkState extends SMCPseudoState {
  SMCForkState(SMCState parent, Type stateType)
      : super(
            parent: parent,
            name: stateType.toString(),
            type: SMCStateType.fork);
  static const fork = 'fork';

  @override
  String get name => ']${super.name}.$fork';
}

/// Will be represented as a UML2 join 'bar' in the diagram
class SMCJoinState extends SMCPseudoState {
  SMCJoinState(SMCState parent, Type stateType)
      : super(
            parent: parent,
            name: stateType.toString(),
            type: SMCStateType.join);
  static const join = 'join';

  @override
  String get name => ']${super.name}.$join';
}

class SMCTerminalState extends SMCPseudoState {
  SMCTerminalState(SMCState parent, Type type)
      : super(
            parent: parent, name: type.toString(), type: SMCStateType.terminal);
  static const finalState = 'final';

  @override
  String get name => ']${super.name}.$finalState';
}
