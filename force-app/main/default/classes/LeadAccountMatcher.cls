public with sharing class LeadAccountMatcher {
    @TestVisible
    private static List<LeadToAccountMatchingCriteria__mdt> leadToAccountCriteria;

    public static List<LeadToAccountMatchingCriteria__mdt> getActiveMatchingCriteria() {
        if (leadToAccountCriteria == null) {
            leadToAccountCriteria = [
                SELECT
                    Lead_Field__c,
                    Account_Field__c,
                    Match_Type__c,
                    Partial_Lead_Start__c,
                    Partial_Account_Start__c,
                    Partial_Lead_End__c,
                    Partial_Account_End__c,
                    Priority__c
                FROM LeadToAccountMatchingCriteria__mdt
                WHERE Active__c = TRUE
                ORDER BY Priority__c ASC
            ];
        }
        return leadToAccountCriteria;
    }

    public static void matchLeadsToAccounts(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        if (newLeads.isEmpty()) {
            return;
        }

        List<LeadToAccountMatchingCriteria__mdt> activeCriteria = getActiveMatchingCriteria();

        if (activeCriteria.isEmpty()) {
            return;
        }

        Map<String, Set<String>> accountFieldToExactMatchSet = new Map<String, Set<String>>();
        Map<String, Set<String>> accountFieldToPartialMatchSet = new Map<String, Set<String>>();

        populateMatchingFieldValues(newLeads, oldLeadMap, accountFieldToExactMatchSet, accountFieldToPartialMatchSet);
        List<Account> accounts = queryPotentialAccounts(accountFieldToExactMatchSet, accountFieldToPartialMatchSet);

        if (!accounts.isEmpty()) {
            Map<String, Map<String, Account>> accountFieldValueToAccount = getAccountFieldValueMap(accounts);
            matchLeads(newLeads, accountFieldValueToAccount);
        }
    }

    @TestVisible
    private static void matchLeads(List<Lead> leads, Map<String, Map<String, Account>> accountFieldValueToAccount) {
        for (Lead lead : leads) {
            for (LeadToAccountMatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String leadFieldValue = (String) lead.get(criteria.Lead_Field__c);
                if (leadFieldValue != null) {
                    if (criteria.Match_Type__c == 'Partial') {
                        leadFieldValue = extractPartialValue(
                            leadFieldValue,
                            criteria.Partial_Lead_Start__c,
                            criteria.Partial_Lead_End__c
                        );
                    }
                    if (accountFieldValueToAccount.containsKey(criteria.Account_Field__c)) {
                        Map<String, Account> accountValueToAccount = accountFieldValueToAccount.get(
                            criteria.Account_Field__c
                        );
                        leadFieldValue = leadFieldValue.trim().toLowerCase();
                        if (accountValueToAccount.containsKey(leadFieldValue)) {
                            Account account = accountValueToAccount.get(leadFieldValue);
                            lead.Account__c = account.Id;
                            lead.Company = account.Name;
                            lead.Website = account.Website;
                            break;
                        }
                    }
                }
            }
        }
    }

    @TestVisible
    private static Map<String, Map<String, Account>> getAccountFieldValueMap(List<Account> accounts) {
        Map<String, Map<String, Account>> accountFieldValueToAccount = new Map<String, Map<String, Account>>();
        for (Account account : accounts) {
            for (LeadToAccountMatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String accountFieldValue = (String) account.get(criteria.Account_Field__c);
                if (accountFieldValue != null) {
                    if (!accountFieldValueToAccount.containsKey(criteria.Account_Field__c)) {
                        accountFieldValueToAccount.put(criteria.Account_Field__c, new Map<String, Account>());
                    }
                    if (criteria.Match_Type__c == 'Partial') {
                        accountFieldValue = extractPartialValue(
                            accountFieldValue,
                            criteria.Partial_Account_Start__c,
                            criteria.Partial_Account_End__c
                        );
                    }
                    accountFieldValueToAccount.get(criteria.Account_Field__c)
                        .put(accountFieldValue.trim().toLowerCase(), account);
                }
            }
        }
        return accountFieldValueToAccount;
    }

    @TestVisible
    private static List<Account> queryPotentialAccounts(
        Map<String, Set<String>> accountFieldToExactMatchSet,
        Map<String, Set<String>> accountFieldToPartialMatchSet
    ) {
        // currently if the lead field lenght is more than the account field our query will not find it.
        // We need some kind of fuzzy matching for them later.

        List<String> conditions = new List<String>();
        Map<String, Object> bindParams = new Map<String, Object>();
        Integer bindCounter = 0;

        for (String fieldName : accountFieldToExactMatchSet.keySet()) {
            Set<String> values = accountFieldToExactMatchSet.get(fieldName);
            if (!values.isEmpty()) {
                conditions.add(fieldName + ' IN :bind' + bindCounter);
                bindParams.put('bind' + bindCounter, values);
                bindCounter++;
            }
        }

        for (String fieldName : accountFieldToPartialMatchSet.keySet()) {
            Set<String> values = accountFieldToPartialMatchSet.get(fieldName);
            if (!values.isEmpty()) {
                conditions.add(fieldName + ' LIKE :bind' + bindCounter);
                bindParams.put('bind' + bindCounter, values);
                bindCounter++;
            }
        }

        if (!conditions.isEmpty()) {
            String query = 'SELECT Id, Name, Website FROM Account';
            query += ' WHERE ' + String.join(conditions, ' OR ');
            query += ' LIMIT 10000';
            return Database.queryWithBinds(query, bindParams, AccessLevel.USER_MODE);
        }
        return new List<Account>();
    }

    @TestVisible
    private static void populateMatchingFieldValues(
        List<Lead> newLeads,
        Map<Id, Lead> oldLeadMap,
        Map<String, Set<String>> accountFieldToExactMatchSet,
        Map<String, Set<String>> accountFieldToPartialMatchSet
    ) {
        for (Lead lead : newLeads) {
            Lead oldLead = oldLeadMap.get(lead.Id);
            for (LeadToAccountMatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String leadFieldValue = (String) lead.get(criteria.Lead_Field__c);
                String oldLeadFieldValue = oldLead == null ? null : (String) oldLead.get(criteria.Lead_Field__c);
                if (isFieldChanged(leadFieldValue, oldLeadFieldValue) && leadFieldValue != null) {
                    switch on criteria.Match_Type__c {
                        when 'Exact' {
                            populateMatchedValues(
                                accountFieldToExactMatchSet,
                                criteria.Account_Field__c,
                                leadFieldValue.trim().toLowerCase()
                            );
                        }
                        when 'Partial' {
                            String partialLeadValue = extractPartialValue(
                                leadFieldValue,
                                criteria.Partial_Lead_Start__c,
                                criteria.Partial_Lead_End__c
                            );
                            populateMatchedValues(
                                accountFieldToPartialMatchSet,
                                criteria.Account_Field__c,
                                '%' + partialLeadValue.trim().toLowerCase() + '%'
                            );
                        }
                    }
                }
            }
        }
    }

    private static void populateMatchedValues(
        Map<String, Set<String>> fieldToMatchSet,
        String fieldName,
        String value
    ) {
        if (value != null) {
            if (fieldToMatchSet.containsKey(fieldName)) {
                fieldToMatchSet.get(fieldName).add(value);
            } else {
                fieldToMatchSet.put(fieldName, new Set<String>{ value });
            }
        }
    }

    private static Boolean isFieldChanged(String newValue, String oldValue) {
        return oldValue == null ||
            (newValue != null && !newValue.trim().equalsIgnoreCase(oldValue.trim().toLowerCase()));
    }

    private static String extractPartialValue(String value, String startFrom, String endAt) {
        if (String.isNotBlank(startFrom)) {
            Integer startIndex = value.indexOf(startFrom);
            if (startIndex >= 0) {
                value = value.substring(startIndex + startFrom.length());
            }
        }
        if (String.isNotBlank(endAt)) {
            Integer endIndex = value.indexOf(endAt);
            if (endIndex >= 0) {
                value = value.substring(0, endIndex);
            }
        }
        return value;
    }
}
