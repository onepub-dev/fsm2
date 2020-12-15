import 'package:fsm2/fsm2.dart';
import 'package:fsm2/src/builders/co_region_builder.dart';
import 'package:fsm2/src/builders/state_builder.dart';
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
    final fsm = createMachine();
    expect(fsm.analyse(), equals(true));
  });

  test('Export', () async {
    final fsm = createMachine();
    const file = 'test/smcat/registration.smcat';
    // var exports =
    fsm.export(file);

    // for (var page in exports.pages) {
    //   var lines = read(page.path).toList().reduce((value, line) => value += '\n' + line);
    //   expect(lines, equals(graph));
    // }
  });
}

StateMachine createMachine() {
  final stateMachine = StateMachine.create(
      (g) => g
        ..initialState<AppLaunched>()

        /// AppLaunched
        ..state<AppLaunched>((builder) => builder
          ..onEnter((s, e) async => fetchUserStatus())
          ..on<OnForceRegistration, RegistrationRequired>(
              sideEffect: (e) async => RegistrationWizard.restart())
          // ignore: avoid_print
          ..on<OnMissingApiKey, RegistrationRequired>(
              // ignore: avoid_print
              sideEffect: (e) async => print('hi'))
          ..on<OnHasApiKey, Registered>())

        /// Registered is normally the final state we are looking for
        /// but there a few circumstance where we force the user to register.
        ..state<Registered>((builder) => builder
          ..on<OnForceRegistration, RegistrationRequired>(
              sideEffect: (e) async => RegistrationWizard.restart))

        ///RegistrationRequired
        ..coregion<RegistrationRequired>(
            (builder) => registrationRequired(builder))
        ..state<AskCAForInvite>((b) {})
        ..onTransition(log),
      production: true);

  return stateMachine;
}

void registrationRequired(StateBuilder<RegistrationRequired> builder) {
  builder
    ..on<OnRegistrationType, AcceptInvitation>(
        condition: (e) => e.type == RegistrationType.acceptInvite,
        conditionLabel: 'AcceptInvite')
    ..on<OnRegistrationType, NewOrganisation>(
        condition: (e) => e.type == RegistrationType.newOrganisation,
        conditionLabel: 'New Organisation')
    ..on<OnRegistrationType, RecoverAccount>(
        condition: (e) => e.type == RegistrationType.recoverAccount,
        conditionLabel: 'Recover Account')

    /// HasRegistrationType
    ..state<RegistrationTypeSelected>(
        (builder) => registrationTypeSelected(builder))
    ..pageBreak
    ..state<RegionPage>((builder) => regionPage(builder))
    ..state<NamePage>((builder) => namePage(builder))
    ..state<EmailPage>((b) => emailPage(b))
    ..state<TrialPhonePage>((builder) => trialPhonePage(builder))

    /// for missing transitions
    ..on<OnTrialNotRequired, TrialRequired>(condition: (e) => true)
    ..on<OnTrialNotRequired, TrialPhonePage>(condition: (e) => true)
    ..on<OnTrialNotRequired, TrialAcquired>(condition: (e) => true)
    ..on<OnTrialNotRequired, NamePage>(condition: (e) => true)
    ..on<OnTrialNotRequired, TrailRequired>(condition: (e) => true)
    ..on<OnTrialNotRequired, EmailPage>(condition: (e) => true)
    ..state<TrailRequired>((_) {})
    ..state<TrialAcquired>((_) {})
    ..state<TrialNotRequired>((_) {});
}

StateBuilder<RegistrationTypeSelected> registrationTypeSelected(
    StateBuilder<RegistrationTypeSelected> builder) {
  return builder
    ..pageBreak
    ..state<NewOrganisation>((builder) => builder
      ..onEnter((s, e) async =>
          RegistrationWizard.setType(RegistrationType.acceptInvite)))
    ..state<RecoverAccount>((builder) => builder
      ..onEnter((s, e) async =>
          RegistrationWizard.setType(RegistrationType.newOrganisation))
      ..on<OnUserNotFound, EmailRequired>())
    ..state<AcceptInvitation>((builder) => acceptInvitation(builder))
    ..coregion<MobileAndRegistrationTypeAcquired>(
        (builder) => mobileAndRegistationTypeAcquired(builder));
}

StateBuilder<AcceptInvitation> acceptInvitation(
    StateBuilder<AcceptInvitation> builder) {
  return builder
    ..onEnter((s, e) async =>
        RegistrationWizard.setType(RegistrationType.recoverAccount))
    ..on<NoInviteFound, AskCAForInvite>()
    ..on<ExpiredInvite, AskCAForInvite>()
    ..on<OnUserNotFound, EmailRequired>()
    ..on<OnUserEnteredMobile, MobileNoAcquired>();
}

class NoInviteFound extends Event {}

class ExpiredInvite extends Event {}

class AskCAForInvite extends State {}

CoRegionBuilder<MobileAndRegistrationTypeAcquired>
    mobileAndRegistationTypeAcquired(
        CoRegionBuilder<MobileAndRegistrationTypeAcquired> builder) {
  return builder
    ..state<EmailNotRequired>((_) {})
    ..state<AcquireMobileNo>((builder) => builder
      ..on<OnUserEnteredMobile, MobileNoAcquired>()

      /// HasMobileNo
      ..state<MobileNoAcquired>((builder) => builder
        ..pageBreak
        ..onEnter((s, e) async => fetchUserDetails())
        ..on<OnMobileValidated, AcquireUser>()

        /// we fetch the user's state based on their mobile.
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

        // hacks for missing states
        ..state<AccountDisabledTerminal>((_) {})
        ..state<UserAcquistionRetryRequired>((_) {})
        ..state<InactiveCustomerTerminal>((_) {})
        ..state<ActiveCustomer>((_) {})
        ..state<ViableInvitation>((_) {})
        ..state<TrialRequired>((_) {})
        ..state<TrailAcquired>((_) {})));
}

StateBuilder<EmailPage> emailPage(StateBuilder<EmailPage> b) {
  return b
    ..initialState<EmailRequired>()
    ..pageBreak
    ..on<OnEmailInvalid, EmailRequired>()
    ..on<OnEmailValidated, EmailAcquired>()
    ..on<OnEmailNotRequired, EmailNotRequired>()
    ..state<EmailRequired>((_) {})
    ..state<EmailAcquired>((_) {});
}

StateBuilder<NamePage> namePage(StateBuilder<NamePage> builder) {
  return builder
    ..initialState<NameRequired>()
    ..pageBreak
    ..on<OnNameInvalid, NameRequired>()
    ..on<OnNameValidated, NameAcquired>()
    ..on<OnNameNotRequired, NameNotRequired>()
    ..state<NameRequired>((_) {})
    ..state<NameAcquired>((_) {})
    ..state<NameNotRequired>((_) {});
}

StateBuilder<TrialPhonePage> trialPhonePage(
    StateBuilder<TrialPhonePage> builder) {
  return builder
    ..initialState<TrialRequired>()
    ..pageBreak
    ..on<OnTrailInvalid, TrialRequired>()
    ..on<OnTrailValidated, TrailAcquired>()
    ..on<OnTrialNotRequired, TrialNotRequired>();
}

StateBuilder<RegionPage> regionPage(StateBuilder<RegionPage> builder) {
  return builder
    ..initialState<RegionRequired>()
    ..pageBreak
    ..on<OnRegionInvalid, RegionRequired>()
    ..on<OnRegionValidated, RegionAcquired>()
    ..on<OnRegionNotRequired, RegionNotRequired>()
    ..state<RegionRequired>((_) {})
    ..state<RegionAcquired>((_) {})
    ..state<RegionNotRequired>((_) {});
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

class RegistrationTypeSelected implements State {}

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

// ignore: unused_element
var _graph = '''

AppLaunched {
	AppLaunched => RegistrationRequired : OnForceRegistration;
	AppLaunched => RegistrationRequired : OnMissingApiKey;
	AppLaunched => Registered : OnHasApiKey;
},
Registered {
	Registered => RegistrationRequired : OnForceRegistration;
},
RegistrationRequired {
	RegistrationTypeAcquired {
		NewOrganisation,
		RecoverAccount {
			RecoverAccount => EmailRequired : OnUserNotFound;
		},
		AcceptInvitation {
			AcceptInvitation => EmailRequired : OnUserNotFound;
			AcceptInvitation => MobileNoAcquired : OnUserEnteredMobile;
		},
		MobileAndRegistrationTypeAcquired.parallel [label="MobileAndRegistrationTypeAcquired"] {
			AcquireMobileNo {
				MobileNoAcquired {
					AcquireUser {
						AcquireUser => EmailRequired : OnUserNotFound;
						AcquireUser => AccountDisabledTerminal : OnUserDisabled;
						AcquireUser => AccountEnabled : OnUserEnabled;
						AcquireUser => UserAcquistionRetryRequired : OnUserAcquisitionFailed;
					},
					AccountEnabled {
						AccountEnabled => InactiveCustomerTerminal : OnInActiveCustomerFound;
						AccountEnabled => ActiveCustomer : OnActiveCustomerFound;
						AccountEnabled => ViableInvitation : OnViableInvitiationFound;
					},
					Pages.parallel [label="Pages"] {
						RegionPage {
							RegionRequired,
							RegionAcquired,
							RegionNotRequired;
							RegionRequired.initial => RegionRequired;
							RegionPage => RegionRequired : OnRegionInvalid;
							RegionPage => RegionAcquired : OnRegionValidated;
							RegionPage => RegionNotRequired : OnRegionNotRequired;
						},
						TrialPhonePage,
						TrailRequired,
						TrialAcquired,
						TrialNotRequired;
						Pages.parallel => TrialRequired : OnTrailInvalid;
						Pages.parallel => TrailAcquired : OnTrailValidated;
						Pages.parallel => TrialNotRequired : OnTrialNotRequired;
					},
					NamePage,
					NameRequired,
					NameAcquired,
					NameNotRequired;
					AcquireUser.initial => AcquireUser;
					MobileNoAcquired => AcquireUser : OnMobileValidated;
					MobileNoAcquired => NameRequired : OnNameInvalid;
					MobileNoAcquired => NameAcquired : OnNameValidated;
					MobileNoAcquired => NameNotRequired : OnNameNotRequired;
				},
				EmailPage,
				EmailRequired,
				EmailAcquired,
				EmailNotRequired;
				MobileNoAcquired.initial => MobileNoAcquired;
				AcquireMobileNo => MobileNoAcquired : OnUserEnteredMobile;
				AcquireMobileNo => EmailRequired : OnEmailInvalid;
				AcquireMobileNo => EmailAcquired : OnEmailValidated;
				AcquireMobileNo => EmailNotRequired : OnEmailNotRequired;
			};
		};
		NewOrganisation.initial => NewOrganisation;
	};
	RegistrationTypeAcquired.initial => RegistrationTypeAcquired;
	RegistrationRequired => AcceptInvitation : OnRegistrationType;
	RegistrationRequired => NewOrganisation : OnRegistrationType;
	RegistrationRequired => RecoverAccount : OnRegistrationType;
};
initial => AppLaunched : AppLaunched;''';
