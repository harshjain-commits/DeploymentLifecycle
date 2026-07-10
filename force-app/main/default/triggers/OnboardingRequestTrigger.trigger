trigger OnboardingRequestTrigger on Onboarding_Request__c(before insert) {
  if (Trigger.isBefore && Trigger.isInsert) {
    OnboardingRequestTriggerHandler.beforeInsert(Trigger.new);
  }
}
