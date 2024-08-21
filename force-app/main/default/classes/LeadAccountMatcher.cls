public with sharing class LeadAccountMatcher extends MatcherService {
    public override String getMatchingObject() {
        return 'Account';
    }

    public override List<String> getTargetObjectFields() {
        return new List<String>{ 'Id', 'Name', 'Website' };
    }

    public override void matchRecords(List<SObject> records, Map<String, Map<String, SObject>> fieldValueToRecordMap) {
        List<Lead> leads = (List<Lead>) records;
        for (Lead lead : leads) {
            for (MatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String leadFieldValue = (String) lead.get(criteria.Field_One__c);
                if (leadFieldValue != null) {
                    if (criteria.Match_Type__c == 'Partial') {
                        leadFieldValue = extractPartialValue(
                            leadFieldValue,
                            criteria.Partial_Field_One_Start__c,
                            criteria.Partial_Field_One_End__c
                        );
                    }
                    if (fieldValueToRecordMap.containsKey(criteria.Field_Two__c)) {
                        Map<String, SObject> accountValueToAccount = fieldValueToRecordMap.get(criteria.Field_Two__c);
                        leadFieldValue = leadFieldValue.trim().toLowerCase();
                        if (accountValueToAccount.containsKey(leadFieldValue)) {
                            Account account = (Account) accountValueToAccount.get(leadFieldValue);
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
}