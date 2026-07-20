// Intentionally thin trigger. All business logic lives in
// OnboardingRequestService so it stays unit-testable outside a trigger
// context and reusable from Flow / Agentforce actions.
//
// The single call below (delegation to a handler class) is the recommended
// Salesforce trigger pattern; PMD's AvoidLogicInTrigger rule flags it as a
// false positive and is downgraded to Info in code-analyzer.yml.
trigger OnboardingRequestTrigger on Onboarding_Request__c(before insert) {
  if (Trigger.isBefore && Trigger.isInsert) {
    OnboardingRequestTriggerHandler.beforeInsert(Trigger.new);
  }
}
