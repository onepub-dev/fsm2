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
  test('registration', () {
    var fsm = createMachine();
    expect(fsm.analyse(), equals(true));
  });
}

StateMachine createMachine() {
  var stateMachine = StateMachine.create((g) => g
    ..initialState<AppLaunched>()

    /// AppLaunched
    ..state<AppLaunched>((builder) => builder
      ..onEnter((s, e) => fetchUserStatus())
      ..on<OnForceRegistration, RegistrationRequired>(sideEffect: () => RegistrationWizard.restart())
      ..onDynamic<OnMissingApiKey>(
          (s, e) => builder.transitionTo<RegistrationRequired>( sideEffect: () => print('hi')))
      ..on<OnHasApiKey, Registered>())

    /// Registered is normally the final state we are looking for
    /// but there a few circumstance where we force the user to register.
    ..state<Registered>((builder) =>
        builder..on<OnForceRegistration, RegistrationRequired>(sideEffect: () => RegistrationWizard.restart))

    ///RegistrationRequired
    ..state<RegistrationRequired>((builder) => builder
      ..on<OnUserSelectedRegistrationType, AcceptInvitation>(
          condition: (s, e) => e.type == RegistrationType.acceptInvite)
      ..on<OnUserSelectedRegistrationType, NewOrganisation>(
          condition: (s, e) => e.type == RegistrationType.newOrganisation)
      ..on<OnUserSelectedRegistrationType, RecoverAccount>(
          condition: (s, e) => e.type == RegistrationType.recoverAccount)

      /// HasRegistrationType
      ..state<RegistrationTypeAcquired>((builder) => builder
        ..state<NewOrganisation>(
            (builder) => builder..onEnter((s, e) => RegistrationWizard.setType(RegistrationType.acceptInvite)))
        ..state<RecoverAccount>(
            (builder) => builder..onEnter((s, e) => RegistrationWizard.setType(RegistrationType.newOrganisation)))
        ..state<AcceptInvitation>(
            (builder) => builder..onEnter((s, e) => RegistrationWizard.setType(RegistrationType.recoverAccount)))
        ..costate<MobileAndRegistrationTypeAcquired>((builder) => builder
          ..state<RegistrationTypeAcquired>((builder) => builder
            ..state<NewOrganisation>((_) => {})
            ..state<RecoverAccount>((_) => {})
            ..state<AcceptInvitation>((_) => {})
            ..state<AcquireMobileNo>((builder) => builder
              ..on<OnUserEnteredMobile, MobileNoAcquired>()

              /// HasMobileNo
              ..state<MobileNoAcquired>((builder) => builder
                ..onEnter((s, e) => fetchUserDetails())
                ..on<OnMobileValidated, AcquireUser>()
                ..state<NewOrganisation>((_) => {})
                ..state<RecoverAccount>((_) => {})
                ..state<AcceptInvitation>((builder) =>
                    builder..on<OnUserNotFound, EmailRequired>()..on<OnUserEnteredMobile, MobileNoAcquired>())

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
                ..costate<Pages>((builder) => builder
                  ..state<RegionPage>((builder) => builder
                    ..initialState(RegionRequired)
                    ..on<OnRegionInvalid, RegionRequired>()
                    ..on<OnRegionValidated, RegionAcquired>()
                    ..on<OnRegionNotRequired, RegionNotRequired>()
                    ..state<RegionRequired>((_) => {})
                    ..state<RegionAcquired>((_) => {})
                    ..state<RegionNotRequired>((_) => {}))
                  ..state<TrialPhonePage>((builder) => builder
                    ..initialState(TrialRequired)
                    ..on<OnTrailInvalid, TrialRequired>()
                    ..on<OnTrailValidated, TrailAcquired>()
                    ..on<OnTrialNotRequired, TrialNotRequired>()
                    ..state<TrailRequired>((_) => {})
                    ..state<TrialAcquired>((_) => {})
                    ..state<TrialNotRequired>((_) => {}))
                  ..state<NamePage>((builder) => builder
                    ..initialState(NameRequired)
                    ..on<OnNameInvalid, NameRequired>()
                    ..on<OnNameValidated, NameAcquired>()
                    ..on<OnNameNotRequired, NameNotRequired>()
                    ..state<NameRequired>((_) => {})
                    ..state<NameAcquired>((_) => {})
                    ..state<NameNotRequired>((_) => {}))
                  ..state<EmailPage>((builder) => builder
                    ..initialState(EmailRequired)
                    ..on<OnEmailInvalid, EmailRequired>()
                    ..on<OnEmailValidated, EmailAcquired>()
                    ..on<OnEmailNotRequired, EmailNotRequired>()
                    ..state<EmailReqired>((_) => {})
                    ..state<EmailAcquired>((_) => {})
                    ..state<EmailNotRequired>((_) => {})))))))))
    ..onTransition(log));

  return stateMachine;
}

class OnEmailNotRequired extends Event {}

class OnNameNotRequired extends Event {}

class EmailReqired extends State {}

class EmailNotRequired extends State {}

class OnEmailValidated extends Event {}

class EmailAcquired extends State {}

class OnEmailInvalid extends Event {}

class EmailPage extends State {}

class NameNotRequired extends State {}

class OnNameValidated extends Event {}

class NameAcquired extends State {}

class OnNameInvalid extends Event {}

class NameRequired extends State {}

class NamePage extends State {}

class TrialAcquired extends State {}

class TrailRequired extends State {}

class TrialNotRequired extends State {}

class OnTrialNotRequired extends Event {}

class TrailAcquired extends State {}

class OnTrailValidated extends Event {}

class OnTrailInvalid extends Event {}

class TrialRequired extends State {}

class TrialPhonePage extends State {}

class RegionAcquired extends State {}

class RegionNotRequired extends State {}

class OnRegionNotRequired extends Event {}

class OnRegionValidated extends Event {}

class OnRegionInvalid extends Event {}

class RegionRequired extends State {}

class RegionPage extends State {}

class Pages extends State {}

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

class OnUserSelectedRegistrationType implements Event {
  var type;
}

void log(TransitionDefinition p1) {}
