/**
 * Tests for OnboardingRequestService and OnboardingRequestTrigger.
 *
 * Goal: drive >90% line coverage on the service class and exercise the
 * pipeline's "coverage to merge" guardrail described in the DevSecOps
 * strategy presentation.
 *
 * Every test wraps its body in System.runAs so the assertions are
 * evaluated in the running user's sharing/CRUD context, not systm
 * context (PMD.ApexUnitTestClassShouldHaveRunAs).
 */
@IsTest
private class OnboardingRequestServiceTest {
  private static User runningUser() {
    return new User(Id = UserInfo.getUserId());
  }

  @IsTest
  static void applyOnboardingRulesSetsDefaultsForBlankStatus() {
    System.runAs(runningUser()) {
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
  }

  @IsTest
  static void applyOnboardingRulesUpliftsHighNetWorth() {
    System.runAs(runningUser()) {
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
  }

  @IsTest
  static void applyOnboardingRulesUpliftsUltraHighNetWorth() {
    System.runAs(runningUser()) {
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
  }

  @IsTest
  static void applyOnboardingRulesHandlesNullAndEmptyInput() {
    System.runAs(runningUser()) {
      OnboardingRequestService.applyOnboardingRules(null);
      OnboardingRequestService.applyOnboardingRules(
        new List<Onboarding_Request__c>()
      );
      System.assert(true, 'Null/empty input must not throw');
    }
  }

  @IsTest
  static void applyOnboardingRulesPreservesExistingStatusAndDate() {
    System.runAs(runningUser()) {
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
  }

  @IsTest
  static void submitOnboardingRequestsInsertsAndReturnsIds() {
    System.runAs(runningUser()) {
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
        SELECT
          Id,
          Customer_Name__c,
          Status__c,
          Priority__c,
          Risk_Score__c,
          Net_Worth_Tier__c
        FROM Onboarding_Request__c
        WHERE Id IN :resultIds
        WITH USER_MODE
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
        // Onboarding_Request_Auto_Triage (BeforeSave flow) marks UHNW as
        // In Review before the before-insert trigger runs. All other tiers
        // fall through to the default of New.
        String expectedStatus = rec.Net_Worth_Tier__c == 'Ultra High Net Worth'
          ? 'In Review'
          : 'New';
        System.assertEquals(
          expectedStatus,
          rec.Status__c,
          'Status should reflect the auto-triage flow for tier ' +
          rec.Net_Worth_Tier__c
        );
      }
    }
  }

  @IsTest
  static void submitOnboardingRequestsHandlesEmptyInput() {
    System.runAs(runningUser()) {
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
  }

  @IsTest
  static void derivePriorityCoversAllBranches() {
    System.runAs(runningUser()) {
      System.assertEquals(
        'Critical',
        OnboardingRequestService.derivePriority(90),
        'Score 90 should be Critical'
      );
      System.assertEquals(
        'High',
        OnboardingRequestService.derivePriority(60),
        'Score 60 should be High'
      );
      System.assertEquals(
        'Medium',
        OnboardingRequestService.derivePriority(10),
        'Score 10 should be Medium'
      );
      System.assertEquals(
        'Medium',
        OnboardingRequestService.derivePriority(null),
        'Null should default to Medium'
      );
    }
  }

  @IsTest
  static void calculateRiskScoreHandlesUnknownTier() {
    System.runAs(runningUser()) {
      Integer score = OnboardingRequestService.calculateRiskScore(
        'Unknown Tier'
      );
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
  }

  @IsTest
  static void triggerPathAppliesRulesOnInsert() {
    System.runAs(runningUser()) {
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
        WITH USER_MODE
      ];
      System.assertEquals('New', reloaded.Status__c);
      System.assertEquals(Date.today(), reloaded.Submitted_Date__c);
      System.assertNotEquals(null, reloaded.Risk_Score__c);
      System.assertNotEquals(null, reloaded.Priority__c);
    }
  }
}
