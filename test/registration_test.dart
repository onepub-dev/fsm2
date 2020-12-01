import 'package:fsm2/fsm2.dart';
import 'package:test/test.dart';

// enum RWStates
// {
// AppLaunched,
// RegistrationRequired
// }

// /// registration wizard events
// enum RWEvents
// {
//   OnForceRegistration
// }
void main() {
  test('analyse', () async {
    var fsm = createMachine();
    expect(await fsm.analyse(), equals(true));
  });

  test('Export', () async {
    var fsm = createMachine();
    await fsm.export('test/gv/registration.gv'); // .then(expectAsync0<bool>(() {}));
    // expectAsync1<bool, String>((a) => machine.export('/tmp/fsm.txt'));
  });

  test('Export', () async {
    var fsm = selectRegistrationType();
    await fsm.export('test/gv/select_registration.gv'); // .then(expectAsync0<bool>(() {}));
    // expectAsync1<bool, String>((a) => machine.export('/tmp/fsm.txt'));
  });
}

StateMachine selectRegistrationType() {
  var stateMachine = StateMachine.create((g) => g
    ..initialState<AppLaunched>()

    /// AppLaunched
    ..state<AppLaunched>((builder) => builder
      ..onEnter((s, e) async => fetchUserStatus())
      ..on<OnForceRegistration, RegistrationRequired>(sideEffect: () async => RegistrationWizard.restart())
      ..on<OnMissingApiKey, RegistrationRequired>(sideEffect: () async => print('hi'))
      ..on<OnHasApiKey, Registered>())

    /// Registered is normally the final state we are looking for
    /// but there a few circumstance where we force the user to register.
    ..state<Registered>((builder) =>
        builder..on<OnForceRegistration, RegistrationRequired>(sideEffect: () async => RegistrationWizard.restart))

    ///RegistrationRequired
    ..state<RegistrationRequired>((builder) => builder
      ..on<OnRegistrationType, AcceptInvitation>(condition: (e) => e.type == RegistrationType.acceptInvite)
      ..on<OnRegistrationType, NewOrganisation>(condition: (e) => e.type == RegistrationType.newOrganisation)
      ..on<OnRegistrationType, RecoverAccount>(condition: (e) => e.type == RegistrationType.recoverAccount)

      /// HasRegistrationType
      ..state<RegistrationTypeAcquired>((builder) => builder
        ..state<NewOrganisation>(
            (builder) => builder..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.acceptInvite)))
        ..state<RecoverAccount>(
            (builder) => builder..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.newOrganisation)))
        ..state<AcceptInvitation>((builder) =>
            builder..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.recoverAccount))))));

  return stateMachine;
}

StateMachine createMachine() {
  var stateMachine = StateMachine.create(
      (g) => g
        ..state<RegistrationTypeAcquired>((builder) => builder
          ..state<NewOrganisation>(
              (builder) => builder..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.acceptInvite)))
          ..state<RecoverAccount>((builder) => builder
            ..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.newOrganisation))
            ..on<OnUserNotFound, EmailRequired>())
          ..state<AcceptInvitation>((builder) => builder
            ..onEnter((s, e) async => RegistrationWizard.setType(RegistrationType.recoverAccount))
            ..on<OnUserNotFound, EmailRequired>()
            ..on<OnUserEnteredMobile, MobileNoAcquired>())
          ..coregion<MobileAndRegistrationTypeAcquired>((builder) => builder
            ..state<AcquireMobileNo>((builder) => builder
              ..on<OnUserEnteredMobile, MobileNoAcquired>()

              /// HasMobileNo
              ..state<MobileNoAcquired>((builder) => builder
                ..onEnter((s, e) async => fetchUserDetails())
                ..on<OnMobileValidated, AcquireUser>()

                /// we fetch the users state based on their mobile.
                ..state<AcquireUser>((builder) => builder
                  ..on<OnUserNotFound, EmailRequired>()
                  ..on<OnUserDisabled, AccountDisabledTerminal>()
                  ..on<OnUserEnabled, AccountEnabled>()
                  ..on<OnUserAcquisitionFailed, UserAcquistionRetryRequired>())

                /// The user's account is active
                ..state<AccountEnabled>((builder) => builder
                  ..on<OnInActiveCustomerFound, InactiveCustomerTerminal>()
                  ..on<OnActiveCustomerFound, ActiveCustomer>()
                  ..on<OnViableInvitiationFound, ViableInvitation>())

                // state for each page in the wizard.
                ..coregion<Pages>((builder) => builder
                  ..state<RegionPage>((builder) => builder
                    ..initialState<RegionRequired>()
                    ..on<OnRegionInvalid, RegionRequired>()
                    ..on<OnRegionValidated, RegionAcquired>()
                    ..on<OnRegionNotRequired, RegionNotRequired>()
                    ..state<RegionRequired>((_) {})
                    ..state<RegionAcquired>((_) {})
                    ..state<RegionNotRequired>((_) {}))
                  ..state<TrialPhonePage>((builder) => builder..initialState<TrialRequired>())
                  ..on<OnTrailInvalid, TrialRequired>()
                  ..on<OnTrailValidated, TrailAcquired>()
                  ..on<OnTrialNotRequired, TrialNotRequired>()
                  ..state<TrailRequired>((_) {})
                  ..state<TrialAcquired>((_) {})
                  ..state<TrialNotRequired>((_) {}))
                ..state<NamePage>((builder) => builder..initialState<NameRequired>())
                ..on<OnNameInvalid, NameRequired>()
                ..on<OnNameValidated, NameAcquired>()
                ..on<OnNameNotRequired, NameNotRequired>()
                ..state<NameRequired>((_) {})
                ..state<NameAcquired>((_) {})
                ..state<NameNotRequired>((_) {}))
              ..state<EmailPage>((builder) => builder..initialState<EmailRequired>())
              ..on<OnEmailInvalid, EmailRequired>()
              ..on<OnEmailValidated, EmailAcquired>()
              ..on<OnEmailNotRequired, EmailNotRequired>()
              ..state<EmailRequired>((_) {})
              ..state<EmailAcquired>((_) {})
              ..state<EmailNotRequired>((_) {}))))
        ..onTransition(log),
      production: true);

  return stateMachine;
}

class OnEmailNotRequired implements Event {}

class OnNameNotRequired implements Event {}

class EmailNotRequired implements State {}

class OnEmailValidated implements Event {}

class EmailAcquired implements State {}

class OnEmailInvalid implements Event {}

class EmailPage implements State {}

class NameNotRequired implements State {}

class OnNameValidated implements Event {}

class NameAcquired implements State {}

class OnNameInvalid implements Event {}

class NameRequired implements State {}

class NamePage implements State {}

class TrialAcquired implements State {}

class TrailRequired implements State {}

class TrialNotRequired implements State {}

class OnTrialNotRequired implements Event {}

class TrailAcquired implements State {}

class OnTrailValidated implements Event {}

class OnTrailInvalid implements Event {}

class TrialRequired implements State {}

class TrialPhonePage implements State {}

class RegionAcquired implements State {}

class RegionNotRequired implements State {}

class OnRegionNotRequired implements Event {}

class OnRegionValidated implements Event {}

class OnRegionInvalid implements Event {}

class RegionRequired implements State {}

class RegionPage implements State {}

class Pages implements State {}

void fetchUserDetails() {}

void fetchUserStatus() {}

class RegistrationWizard {
  static void restart() {}

  static void setType(RegistrationType acceptInvite) {}
}

enum RegistrationType { acceptInvite, newOrganisation, recoverAccount }

/// states

class AppLaunched implements State {}

class RegistrationRequired implements State {}

class RegistrationTypeAcquired implements State {}

class NewOrganisation implements State {}

class RecoverAccount implements State {}

class AcceptInvitation implements State {}

class AcquireMobileNo implements State {}

class MobileNoAcquired implements State {}

class AcquireUser implements State {}

class AccountEnabled implements State {}

class EmailRequired implements State {}

class Registered implements State {}

class AccountDisabledTerminal implements State {}

class InactiveCustomerTerminal implements State {}

class ActiveCustomer implements State {}

class ViableInvitation implements State {}

class UserAcquistionRetryRequired implements State {}

class MobileAndRegistrationTypeAcquired implements State {}

/// events
class OnUserNotFound implements Event {}

class OnInActiveCustomerFound implements Event {}

class OnActiveCustomerFound implements Event {}

class OnViableInvitiationFound implements Event {}

class OnUserEnteredMobile implements Event {}

class OnMobileValidated implements Event {}

class OnUserDisabled implements Event {}

class OnUserEnabled implements Event {}

class OnUserAcquisitionFailed implements Event {}

class OnForceRegistration implements Event {}

class OnMissingApiKey implements Event {}

class OnHasApiKey implements Event {}

class OnRegistrationType implements Event {
  RegistrationType type;
}

void log(StateDefinition from, Event event, StateDefinition to) {}
