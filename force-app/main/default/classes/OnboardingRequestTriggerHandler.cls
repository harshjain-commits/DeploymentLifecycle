/**
 * Trigger handler for Onboarding_Request__c.
 *
 * Kept thin: delegates all business logic to OnboardingRequestService so the
 * logic remains reusable (Apex, Flow, Agentforce action) and unit-testable
 * without DML.
 */
public with sharing class OnboardingRequestTriggerHandler {
  public static void beforeInsert(List<Onboarding_Request__c> newRequests) {
    OnboardingRequestService.applyOnboardingRules(newRequests);
  }
}
