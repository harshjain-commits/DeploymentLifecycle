/**
 * Service class for Bedrock Financial customer onboarding requests.
 *
 * Encapsulates business logic so it can be invoked from a trigger handler,
 * a Flow (via @InvocableMethod), an Apex controller, or an Agentforce action.
 *
 * Used by the Bedrock DevSecOps demo to showcase end-to-end Salesforce
 * delivery: source-control, automated checks, deployment pipeline, and
 * test evidence.
 */
public with sharing class OnboardingRequestService {
  @TestVisible
  private static final Integer DEFAULT_RISK_SCORE = 25;
  @TestVisible
  private static final Integer HIGH_NET_WORTH_RISK_UPLIFT = 20;
  @TestVisible
  private static final Integer ULTRA_HIGH_NET_WORTH_RISK_UPLIFT = 45;
  @TestVisible
  private static final Integer CRITICAL_RISK_THRESHOLD = 75;
  @TestVisible
  private static final Integer HIGH_RISK_THRESHOLD = 50;

  /**
   * Applies onboarding business rules to a list of new requests in-memory.
   * Safe to call from a before-insert trigger.
   *
   * Rules:
   *  - Risk score is derived from net-worth tier (base + uplift).
   *  - Priority is derived from risk score.
   *  - Status defaults to "New" if blank.
   *  - Submitted Date defaults to today if blank.
   *
   * @param requests Onboarding requests being created. Mutated in-place.
   */
  public static void applyOnboardingRules(
    List<Onboarding_Request__c> requests
  ) {
    if (requests == null || requests.isEmpty()) {
      return;
    }
    for (Onboarding_Request__c req : requests) {
      req.Risk_Score__c = calculateRiskScore(req.Net_Worth_Tier__c);
      req.Priority__c = derivePriority(req.Risk_Score__c);
      if (String.isBlank(req.Status__c)) {
        req.Status__c = 'New';
      }
      if (req.Submitted_Date__c == null) {
        req.Submitted_Date__c = Date.today();
      }
    }
  }

  /**
   * Invocable wrapper so the same logic can be reused from a Flow or an
   * Agentforce action. Inserts the requests after applying onboarding rules.
   *
   * @param requests Onboarding requests to insert.
   * @return The Ids of the inserted records, in the same order as input.
   */
  @InvocableMethod(
    label='Submit Onboarding Requests'
    description='Applies onboarding rules and inserts the requests.'
    category='Bedrock Financial'
  )
  public static List<Id> submitOnboardingRequests(
    List<Onboarding_Request__c> requests
  ) {
    if (requests == null || requests.isEmpty()) {
      return new List<Id>();
    }
    applyOnboardingRules(requests);
    insert requests;
    List<Id> ids = new List<Id>();
    for (Onboarding_Request__c req : requests) {
      ids.add(req.Id);
    }
    return ids;
  }

  /**
   * Computes a deterministic risk score based on the customer's net worth tier.
   * Real implementations would call an external KYC/AML service; this stub keeps
   * the demo deterministic and offline-testable.
   *
   * @param netWorthTier Picklist value from Onboarding_Request__c.Net_Worth_Tier__c.
   * @return Risk score 0-100.
   */
  @TestVisible
  private static Integer calculateRiskScore(String netWorthTier) {
    Integer score = DEFAULT_RISK_SCORE;
    if (netWorthTier == 'High Net Worth') {
      score += HIGH_NET_WORTH_RISK_UPLIFT;
    } else if (netWorthTier == 'Ultra High Net Worth') {
      score += ULTRA_HIGH_NET_WORTH_RISK_UPLIFT;
    }
    return score;
  }

  /**
   * Derives a priority bucket from a numeric risk score.
   *
   * @param riskScore Risk score 0-100.
   * @return Priority picklist value.
   */
  @TestVisible
  private static String derivePriority(Integer riskScore) {
    if (riskScore == null) {
      return 'Medium';
    }
    if (riskScore >= CRITICAL_RISK_THRESHOLD) {
      return 'Critical';
    }
    if (riskScore >= HIGH_RISK_THRESHOLD) {
      return 'High';
    }
    return 'Medium';
  }
}
