// Seeds sample Bedrock Financial Onboarding Requests for the demo.
// Run after deploying the BF Onboarding metadata to a sandbox or scratch org:
//
//   sf apex run --file scripts/apex/seed-onboarding-requests.apex
//
// Safe to re-run; it skips inserts if records with the same Customer_Name__c
// already exist.

List<Onboarding_Request__c> samples = new List<Onboarding_Request__c>{
    new Onboarding_Request__c(
        Customer_Name__c = 'Aurora Capital Partners',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Ultra High Net Worth',
        Source_Channel__c = 'Advisor Referral',
        Notes__c = 'Referred by senior advisor; existing CLL client.'
    ),
    new Onboarding_Request__c(
        Customer_Name__c = 'Bedrock Industries Pension',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Ultra High Net Worth',
        Source_Channel__c = 'Partner Channel',
        Notes__c = 'Large corporate pension - white-glove onboarding required.'
    ),
    new Onboarding_Request__c(
        Customer_Name__c = 'Jordan Hayes',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'High Net Worth',
        Source_Channel__c = 'Web',
        Notes__c = 'Self-service inquiry via wealth-management portal.'
    ),
    new Onboarding_Request__c(
        Customer_Name__c = 'Riley Chen',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Mass Affluent',
        Source_Channel__c = 'SMS Campaign',
        Notes__c = 'Responded to Q1 wealth-management SMS campaign.'
    ),
    new Onboarding_Request__c(
        Customer_Name__c = 'Sam Patel',
        Division__c = 'Bedrock Financial',
        Net_Worth_Tier__c = 'Mass Affluent',
        Source_Channel__c = 'Email Campaign',
        Notes__c = 'Cross-sell candidate from Bedrock Healthcare CRM.'
    )
};

Set<String> sampleNames = new Set<String>();
for (Onboarding_Request__c req : samples) {
    sampleNames.add(req.Customer_Name__c);
}

Set<String> existingNames = new Set<String>();
for (Onboarding_Request__c existing : [
    SELECT Customer_Name__c FROM Onboarding_Request__c WHERE Customer_Name__c IN :sampleNames
]) {
    existingNames.add(existing.Customer_Name__c);
}

List<Onboarding_Request__c> toInsert = new List<Onboarding_Request__c>();
for (Onboarding_Request__c req : samples) {
    if (!existingNames.contains(req.Customer_Name__c)) {
        toInsert.add(req);
    }
}

if (toInsert.isEmpty()) {
    System.debug('No new onboarding requests to seed - all sample customers already exist.');
} else {
    insert toInsert;
    System.debug('Seeded ' + toInsert.size() + ' onboarding requests.');
    for (Onboarding_Request__c rec : [
        SELECT Name, Customer_Name__c, Priority__c, Risk_Score__c, Status__c
        FROM Onboarding_Request__c
        WHERE Id IN :toInsert
    ]) {
        System.debug(
            rec.Name +
            ' | ' +
            rec.Customer_Name__c +
            ' | Priority=' +
            rec.Priority__c +
            ' | Risk=' +
            rec.Risk_Score__c +
            ' | Status=' +
            rec.Status__c
        );
    }
}
