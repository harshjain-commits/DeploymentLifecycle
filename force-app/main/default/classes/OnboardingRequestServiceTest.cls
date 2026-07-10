/**
 * Tests for OnboardingRequestService and OnboardingRequestTrigger.
 *
 * Goal: drive >90% line coverage on the service class and exercise the
 * pipeline's "coverage to merge" guardrail described in the DevSecOps
 * strategy presentation.
 */
@IsTest
private class OnboardingRequestServiceTest {
  @IsTest
  static void applyOnboardingRules_sets_defaults_for_blank_status() {
    Onboarding_Request__c req = new Onboarding_Request__c(
      Customer_Name__c = 'Acme Industries',
      Division__c = 'Bedrock Financial',
      Net_Worth_Tier__c = 'Mass Affluent'
    );

    Test.startTest();
    OnboardingRequestService.applyOnboardingRules(
      new List<Onboarding_Request__c>{ req }
    );
    Test.stopTest();

    System.assertEquals('New', req.Status__c, 'Status should default to New');
    System.assertEquals(
      Date.today(),
      req.Submitted_Date__c,
      'Submitted Date should default to today'
    );
    System.assertEquals(
      OnboardingRequestService.DEFAULT_RISK_SCORE,
      (Integer) req.Risk_Score__c,
      'Risk Score should match the default for Mass Affluent'
    );
    System.assertEquals(
      'Medium',
      req.Priority__c,
      'Mass Affluent should map to Medium priority'
    );
  }

  @IsTest
  static void applyOnboardingRules_uplifts_high_net_worth() {
    Onboarding_Request__c req = new Onboarding_Request__c(
      Customer_Name__c = 'Jane Doe',
      Division__c = 'Bedrock Financial',
      Net_Worth_Tier__c = 'High Net Worth'
    );

    OnboardingRequestService.applyOnboardingRules(
      new List<Onboarding_Request__c>{ req }
    );

    Integer expected =
      OnboardingRequestService.DEFAULT_RISK_SCORE +
      OnboardingRequestService.HIGH_NET_WORTH_RISK_UPLIFT;
    System.assertEquals(
      expected,
      (Integer) req.Risk_Score__c,
      'HNW uplift should apply'
    );
    System.assertEquals(
      'Medium',
      req.Priority__c,
      'Score below 50 should remain Medium'
    );
  }

  @IsTest
  static void applyOnboardingRules_marks_uhnw_as_critical() {
    Onboarding_Request__c req = new Onboarding_Request__c(
      Customer_Name__c = 'Ultra Holdings',
      Division__c = 'Bedrock Financial',
      Net_Worth_Tier__c = 'Ultra High Net Worth'
    );

    OnboardingRequestService.applyOnboardingRules(
      new List<Onboarding_Request__c>{ req }
    );

    Integer expected =
      OnboardingRequestService.DEFAULT_RISK_SCORE +
      OnboardingRequestService.ULTRA_HIGH_NET_WORTH_RISK_UPLIFT;
    System.assertEquals(
      expected,
      (Integer) req.Risk_Score__c,
      'UHNW uplift should apply'
    );
    System.assertEquals(
      'High',
      req.Priority__c,
      'UHNW score of 70 should cross the High threshold'
    );
  }

  @IsTest
  static void applyOnboardingRules_handles_null_and_empty_input() {
    OnboardingRequestService.applyOnboardingRules(null);
    OnboardingRequestService.applyOnboardingRules(
      new List<Onboarding_Request__c>()
    );
    System.assert(true, 'Null/empty input must not throw');
  }

  @IsTest
  static void applyOnboardingRules_preserves_existing_status_and_date() {
    Date custom = Date.today().addDays(-3);
    Onboarding_Request__c req = new Onboarding_Request__c(
      Customer_Name__c = 'Existing Status',
      Division__c = 'Bedrock Healthcare',
      Net_Worth_Tier__c = 'Mass Affluent',
      Status__c = 'In Review',
      Submitted_Date__c = custom
    );

    OnboardingRequestService.applyOnboardingRules(
      new List<Onboarding_Request__c>{ req }
    );

    System.assertEquals(
      'In Review',
      req.Status__c,
      'Pre-set status must be preserved'
    );
    System.assertEquals(
      custom,
      req.Submitted_Date__c,
      'Pre-set submitted date must be preserved'
    );
  }

  @IsTest
  static void submitOnboardingRequests_inserts_and_returns_ids() {
    List<Onboarding_Request__c> toCreate = new List<Onboarding_Request__c>{
      new Onboarding_Request__c(
        Customer_Name__c = 'Customer A',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Mass Affluent'
      ),
      new Onboarding_Request__c(
        Customer_Name__c = 'Customer B',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Ultra High Net Worth'
      )
    };

    Test.startTest();
    List<Id> resultIds = OnboardingRequestService.submitOnboardingRequests(
      toCreate
    );
    Test.stopTest();

    System.assertEquals(2, resultIds.size(), 'Two ids should be returned');
    List<Onboarding_Request__c> persisted = [
      SELECT Id, Status__c, Priority__c, Risk_Score__c
      FROM Onboarding_Request__c
      WHERE Id IN :resultIds
      ORDER BY Customer_Name__c
    ];
    System.assertEquals(
      2,
      persisted.size(),
      'Both records should be persisted'
    );
    for (Onboarding_Request__c rec : persisted) {
      System.assertNotEquals(
        null,
        rec.Risk_Score__c,
        'Risk score should be populated by trigger'
      );
      System.assertNotEquals(
        null,
        rec.Priority__c,
        'Priority should be populated by trigger'
      );
      System.assertEquals('New', rec.Status__c, 'Default status should be New');
    }
  }

  @IsTest
  static void submitOnboardingRequests_handles_empty_input() {
    List<Id> result = OnboardingRequestService.submitOnboardingRequests(
      new List<Onboarding_Request__c>()
    );
    System.assertEquals(
      0,
      result.size(),
      'Empty input should return empty list'
    );

    List<Id> resultNull = OnboardingRequestService.submitOnboardingRequests(
      null
    );
    System.assertEquals(
      0,
      resultNull.size(),
      'Null input should return empty list'
    );
  }

  @IsTest
  static void derivePriority_covers_all_branches() {
    // Critical: >= 75
    System.assertEquals(
      'Critical',
      OnboardingRequestService.derivePriority(90),
      'Score 90 should be Critical'
    );
    // High: 50-74
    System.assertEquals(
      'High',
      OnboardingRequestService.derivePriority(60),
      'Score 60 should be High'
    );
    // Medium: < 50
    System.assertEquals(
      'Medium',
      OnboardingRequestService.derivePriority(10),
      'Score 10 should be Medium'
    );
    // Null guard
    System.assertEquals(
      'Medium',
      OnboardingRequestService.derivePriority(null),
      'Null should default to Medium'
    );
  }

  @IsTest
  static void calculateRiskScore_handles_unknown_tier() {
    Integer score = OnboardingRequestService.calculateRiskScore('Unknown Tier');
    System.assertEquals(
      OnboardingRequestService.DEFAULT_RISK_SCORE,
      score,
      'Unknown tier should fall through to the default'
    );

    Integer nullScore = OnboardingRequestService.calculateRiskScore(null);
    System.assertEquals(
      OnboardingRequestService.DEFAULT_RISK_SCORE,
      nullScore,
      'Null tier should fall through to the default'
    );
  }

  @IsTest
  static void trigger_path_applies_rules_on_insert() {
    Onboarding_Request__c req = new Onboarding_Request__c(
      Customer_Name__c = 'Trigger Test',
      Division__c = 'Bedrock Financial',
      Net_Worth_Tier__c = 'High Net Worth'
    );

    Test.startTest();
    insert req;
    Test.stopTest();

    Onboarding_Request__c reloaded = [
      SELECT Status__c, Priority__c, Risk_Score__c, Submitted_Date__c
      FROM Onboarding_Request__c
      WHERE Id = :req.Id
    ];
    System.assertEquals('New', reloaded.Status__c);
    System.assertEquals(Date.today(), reloaded.Submitted_Date__c);
    System.assertNotEquals(null, reloaded.Risk_Score__c);
    System.assertNotEquals(null, reloaded.Priority__c);
  }
}
