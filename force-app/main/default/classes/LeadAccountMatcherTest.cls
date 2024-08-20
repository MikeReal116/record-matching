@IsTest
private with sharing class LeadAccountMatcherTest {
    @IsTest
    private static void it_should_populate_exact_match() {
        List<Lead> newLeads = createLeadRecords(200);
        Integer counter = 0;
        for (Lead lead : newLeads) {
            lead.Company += counter++;
            lead.Website = 'www.testcompany.com';
        }
        LeadToAccountMatchingCriteria__mdt exactMatchingCriteria = createExactMatchingCriteria();
        LeadToAccountMatchingCriteria__mdt partialMatchingCriteria = createExactMatchingCriteria();
        partialMatchingCriteria.Account_Field__c = 'Website';
        partialMatchingCriteria.Lead_Field__c = 'Website';
        LeadAccountMatcher.leadToAccountCriteria = new List<LeadToAccountMatchingCriteria__mdt>{
            exactMatchingCriteria,
            partialMatchingCriteria
        };
        Map<String, Set<String>> accountFieldToExactMatchSet = new Map<String, Set<String>>();
        Map<String, Set<String>> accountFieldToPartialMatchSet = new Map<String, Set<String>>();

        LeadAccountMatcher.populateMatchingFieldValues(
            newLeads,
            new Map<Id, Lead>(),
            accountFieldToExactMatchSet,
            accountFieldToPartialMatchSet
        );

        System.Assert.isTrue(accountFieldToExactMatchSet.containsKey('Name'), 'Name field should be populated');
        System.Assert.isTrue(accountFieldToExactMatchSet.containsKey('Website'), 'Website field should be populated');
        System.Assert.isTrue(
            accountFieldToExactMatchSet.get('Name').size() == newLeads.size(),
            'Name field should have 200 unique values'
        );
        System.Assert.isTrue(
            accountFieldToExactMatchSet.get('Website').size() == 1,
            'Website field should have 1 unique value'
        );
        System.Assert.isTrue(accountFieldToPartialMatchSet.isEmpty(), 'Partial match set should be empty');
    }

    @IsTest
    private static void it_should_populate_all_matches() {
        List<Lead> newLeads = createLeadRecords(200);
        String website = 'www.testcompany.com';
        String domain = 'testcompany.com';
        Integer counter = 0;
        for (Lead lead : newLeads) {
            lead.Company += counter++;
            lead.Website = website;
            if (Math.mod(counter, 2) == 0) {
                lead.Website = website + '/home';
                lead.Email = 'firstName.lastName@' + domain;
            }
        }
        LeadToAccountMatchingCriteria__mdt exactMatchingCriteria = createExactMatchingCriteria();
        LeadToAccountMatchingCriteria__mdt partialMatchingCriteria = createPartialMatchingCriteria();
        partialMatchingCriteria.Account_Field__c = 'Email';

        LeadAccountMatcher.leadToAccountCriteria = new List<LeadToAccountMatchingCriteria__mdt>{
            exactMatchingCriteria,
            partialMatchingCriteria
        };
        Map<String, Set<String>> accountFieldToExactMatchSet = new Map<String, Set<String>>();
        Map<String, Set<String>> accountFieldToPartialMatchSet = new Map<String, Set<String>>();

        LeadAccountMatcher.populateMatchingFieldValues(
            newLeads,
            new Map<Id, Lead>(),
            accountFieldToExactMatchSet,
            accountFieldToPartialMatchSet
        );

        System.Assert.isTrue(accountFieldToExactMatchSet.containsKey('Name'), 'Name field should be populated');
        System.Assert.isTrue(accountFieldToPartialMatchSet.containsKey('Email'), 'Email field should be populated');
        System.Assert.isTrue(
            accountFieldToPartialMatchSet.get('Email').size() == 1,
            'Email field should have 1 unique value'
        );
        System.Assert.isTrue(
            accountFieldToPartialMatchSet.get('Email').contains('%' + domain + '%'),
            'Email field should have the correct value'
        );
    }

    @IsTest
    private static void it_should_return_potential_accounts() {
        List<Account> accounts = createAccountRecords(200);
        Integer counter = 1;

        // default account name is 'Test Account'
        for (Account account : accounts) {
            account.Name += counter;
            if (counter <= 10) {
                account.Name = 'Global Corp' + counter;
            }
            account.Website = 'www.testaccount.com';
            if (counter > 10 && counter <= 20) {
                account.website = 'www.globalcorp.com/home';
            }
            counter++;
        }
        insert accounts;

        List<Lead> leads = createLeadRecords(200);
        Integer leadCounter = 1;
        // default lead company is 'Test Company'
        for (Lead lead : leads) {
            lead.Company += leadCounter;
            lead.Email = 'firstName.lastName@testcompany.com';
            if (leadCounter <= 10) {
                lead.Company = 'Global Corp';
            }
            if (leadCounter > 10 && leadCounter <= 20) {
                lead.Email = 'firstName.lastName@globalcorp.com';
            }
            leadCounter++;
        }

        LeadToAccountMatchingCriteria__mdt exactMatchingCriteria = createExactMatchingCriteria();
        LeadToAccountMatchingCriteria__mdt emailCriteria = createPartialMatchingCriteria();

        LeadAccountMatcher.leadToAccountCriteria = new List<LeadToAccountMatchingCriteria__mdt>{
            exactMatchingCriteria,
            emailCriteria
        };

        Map<String, Set<String>> accountFieldToExactMatchSet = new Map<String, Set<String>>();
        Map<String, Set<String>> accountFieldToPartialMatchSet = new Map<String, Set<String>>();

        LeadAccountMatcher.populateMatchingFieldValues(
            leads,
            new Map<Id, Lead>(),
            accountFieldToExactMatchSet,
            accountFieldToPartialMatchSet
        );

        List<Account> potentialAccounts = LeadAccountMatcher.queryPotentialAccounts(
            accountFieldToExactMatchSet,
            accountFieldToPartialMatchSet
        );

        System.Assert.isTrue(potentialAccounts.size() == 10, 'Should have 10 potential accounts');
        System.Assert.isFalse(
            potentialAccounts[0].Name.startsWith('Global Corp'),
            'Global Corp should not be in the potential accounts because of exact match'
        );
    }

    @IsTest
    private static void it_should_populate_matching_account() {
        List<Account> accounts = createAccountRecords(200);
        String accountNameGlobal = 'Global Corp';
        String accountWebsiteGlobal = 'www.globalcorp.com';
        String accountNameLive = 'Live Corp';
        String accountWebsiteLive = 'www.livecorp.com';
        Integer counter = 1;
        for (Account account : accounts) {
            account.Website = 'www.testaccount.com';
            if (counter <= 10) {
                account.Name = accountNameGlobal;
                account.Website = accountWebsiteGlobal;
            }
            if (counter > 10 && counter <= 20) {
                account.Name = accountNameLive;
                account.website = accountWebsiteLive;
            }
            counter++;
        }

        insert accounts;

        List<Lead> leads = createLeadRecords(200);
        Integer leadCounter = 1;
        for (Lead lead : leads) {
            lead.Company += leadCounter;
            lead.Email = 'firstName.lastName@testcompany.com';
            if (leadCounter <= 10) {
                lead.Company = accountNameGlobal;
            }
            if (leadCounter > 10 && leadCounter <= 20) {
                lead.Company = 'Live Corporation';
                lead.Email = 'firstName.LastName@livecorp.com'.toUpperCase();
            }
            leadCounter++;
        }

        LeadToAccountMatchingCriteria__mdt exactMatchingCriteria = createExactMatchingCriteria();
        LeadToAccountMatchingCriteria__mdt partialMatchingCriteria = createPartialMatchingCriteria();

        LeadAccountMatcher.leadToAccountCriteria = new List<LeadToAccountMatchingCriteria__mdt>{
            exactMatchingCriteria,
            partialMatchingCriteria
        };

        LeadAccountMatcher.matchLeadsToAccounts(leads, new Map<Id, Lead>());

        for (Lead lead : leads) {
            if (lead.Company == accountNameGlobal) {
                System.Assert.isTrue(lead.Account__c != null, 'Global Corp should have an account');
                System.Assert.isTrue(lead.Website == accountWebsiteGlobal, 'Website should be ' + accountWebsiteGlobal);
            } else if (lead.Company == accountNameLive) {
                System.Assert.isTrue(lead.Account__c != null, 'Live Corporation should have an account');
                System.Assert.isTrue(lead.Website == accountWebsiteLive, 'Website should be ' + accountWebsiteLive);
            } else {
                System.Assert.isTrue(lead.Account__c == null, 'Lead should not have an account');
            }
        }
    }

    private static List<Account> createAccountRecords(Integer numberOfAccounts) {
        return TestFactory.createSObjectList(new Account(), numberOfAccounts);
    }

    private static List<Lead> createLeadRecords(Integer numberOfLeads) {
        return TestFactory.createSObjectList(new Lead(), numberOfLeads);
    }

    private static LeadToAccountMatchingCriteria__mdt createExactMatchingCriteria() {
        return new LeadToAccountMatchingCriteria__mdt(
            Match_Type__c = 'Exact',
            Account_Field__c = 'Name',
            Lead_Field__c = 'Company',
            Priority__c = 1,
            Active__c = true
        );
    }

    private static LeadToAccountMatchingCriteria__mdt createPartialMatchingCriteria() {
        return new LeadToAccountMatchingCriteria__mdt(
            Account_Field__c = 'Website',
            Lead_Field__c = 'Email',
            Match_Type__c = 'Partial',
            Priority__c = 2,
            Partial_Lead_Start__c = '@',
            Partial_Account_Start__c = 'www.',
            Partial_Account_End__c = '/'
        );
    }
}
