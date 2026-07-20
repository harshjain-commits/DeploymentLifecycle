/**
 * Trigger handler for Onboarding_Request__c.
 *
 * Kept thin: delegates all business logic to OnboardingRequestService so the
 * logic remains reusable (Apex, Flow, Agentforce action) and unit-testable
 * without DML.
 */
public with sharing class OnboardingRequestTriggerHandler {
  /**
   * Before-insert entry point invoked by OnboardingRequestTrigger.
   *
   * Delegates directly to OnboardingRequestService.applyOnboardingRules so
   * the business logic stays testable outside a trigger context and is
   * reusable from Flow / Agentforce / Apex controllers.
   *
   * @param newRequests The Onboarding_Request__c records being inserted.
   */
  public static void beforeInsert(List<Onboarding_Request__c> newRequests) {
    OnboardingRequestService.applyOnboardingRules(newRequests);
  }
}
