public abstract with sharing class MatcherService {
    @TestVisible
    private static List<MatchingCriteria__mdt> matchingCriteria;

    // Child classes should specify what fields to query from the target object.
    public abstract String getMatchingObject();

    // Child classes should specify what fields to query from the target object.
    public abstract List<String> getTargetObjectFields();

    // Child classes should implement what to do after matching the records.
    public abstract void matchRecords(List<SObject> records, Map<String, Map<String, SObject>> fieldValueToRecordMap);

    public List<MatchingCriteria__mdt> getActiveMatchingCriteria() {
        if (matchingCriteria == null) {
            matchingCriteria = [
                SELECT
                    Field_One__c,
                    Field_Two__c,
                    Match_Type__c,
                    Partial_Field_One_Start__c,
                    Partial_Field_Two_Start__c,
                    Partial_Field_One_End__c,
                    Partial_Field_Two_End__c,
                    Priority__c
                FROM MatchingCriteria__mdt
                WHERE Active__c = TRUE AND Matching_Object__c = :getMatchingObject()
                ORDER BY Priority__c ASC
            ];
        }
        return matchingCriteria;
    }

    public void matchRecordsToTarget(List<SObject> newRecords, Map<Id, SObject> oldRecordMap) {
        if (newRecords.isEmpty()) {
            return;
        }

        List<MatchingCriteria__mdt> activeCriteria = getActiveMatchingCriteria();

        if (activeCriteria.isEmpty()) {
            return;
        }

        Map<String, Set<String>> fieldToExactMatchSet = new Map<String, Set<String>>();
        Map<String, Set<String>> fieldToPartialMatchSet = new Map<String, Set<String>>();

        populateMatchingFieldValues(newRecords, oldRecordMap, fieldToExactMatchSet, fieldToPartialMatchSet);
        List<SObject> targetRecords = queryPotentialTargetRecords(fieldToExactMatchSet, fieldToPartialMatchSet);

        if (!targetRecords.isEmpty()) {
            Map<String, Map<String, SObject>> fieldValueToRecordMap = getFieldToRecordMap(targetRecords);
            matchRecords(newRecords, fieldValueToRecordMap);
        }
    }

    @TestVisible
    private Map<String, Map<String, SObject>> getFieldToRecordMap(List<SObject> targetRecords) {
        Map<String, Map<String, SObject>> fieldValueToRecordMap = new Map<String, Map<String, SObject>>();
        for (SObject record : targetRecords) {
            for (MatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String fieldValue = (String) record.get(criteria.Field_Two__c);
                if (fieldValue != null) {
                    if (!fieldValueToRecordMap.containsKey(criteria.Field_Two__c)) {
                        fieldValueToRecordMap.put(criteria.Field_Two__c, new Map<String, SObject>());
                    }
                    if (criteria.Match_Type__c == 'Partial') {
                        fieldValue = extractPartialValue(
                            fieldValue,
                            criteria.Partial_Field_Two_Start__c,
                            criteria.Partial_Field_Two_End__c
                        );
                    }
                    fieldValueToRecordMap.get(criteria.Field_Two__c).put(fieldValue.trim().toLowerCase(), record);
                }
            }
        }
        return fieldValueToRecordMap;
    }

    @TestVisible
    private List<SObject> queryPotentialTargetRecords(
        Map<String, Set<String>> fieldToExactMatchSet,
        Map<String, Set<String>> fieldToPartialMatchSet
    ) {
        List<String> conditions = new List<String>();
        Map<String, Object> bindParams = new Map<String, Object>();
        Integer bindCounter = 0;

        for (String fieldName : fieldToExactMatchSet.keySet()) {
            Set<String> values = fieldToExactMatchSet.get(fieldName);
            if (!values.isEmpty()) {
                conditions.add(fieldName + ' IN :bind' + bindCounter);
                bindParams.put('bind' + bindCounter, values);
                bindCounter++;
            }
        }

        for (String fieldName : fieldToPartialMatchSet.keySet()) {
            Set<String> values = fieldToPartialMatchSet.get(fieldName);
            if (!values.isEmpty()) {
                conditions.add(fieldName + ' LIKE :bind' + bindCounter);
                bindParams.put('bind' + bindCounter, values);
                bindCounter++;
            }
        }

        if (!conditions.isEmpty()) {
            String query = 'SELECT ' + String.join(getTargetObjectFields(), ', ') + ' FROM ' + getMatchingObject();
            query += ' WHERE ' + String.join(conditions, ' OR ');
            query += ' LIMIT 10000';
            return Database.queryWithBinds(query, bindParams, AccessLevel.USER_MODE);
        }
        return new List<SObject>();
    }

    @TestVisible
    private void populateMatchingFieldValues(
        List<SObject> newRecords,
        Map<Id, SObject> oldRecordMap,
        Map<String, Set<String>> fieldToExactMatchSet,
        Map<String, Set<String>> fieldToPartialMatchSet
    ) {
        for (SObject record : newRecords) {
            SObject oldRecord = oldRecordMap.get(record.Id);
            for (MatchingCriteria__mdt criteria : getActiveMatchingCriteria()) {
                String fieldValue = (String) record.get(criteria.Field_One__c);
                String oldFieldValue = oldRecord == null ? null : (String) oldRecord.get(criteria.Field_One__c);
                if (isFieldChanged(fieldValue, oldFieldValue) && fieldValue != null) {
                    switch on criteria.Match_Type__c {
                        when 'Exact' {
                            populateMatchedValues(
                                fieldToExactMatchSet,
                                criteria.Field_Two__c,
                                fieldValue.trim().toLowerCase()
                            );
                        }
                        when 'Partial' {
                            String partialFieldValue = extractPartialValue(
                                fieldValue,
                                criteria.Partial_Field_One_Start__c,
                                criteria.Partial_Field_One_End__c
                            );
                            populateMatchedValues(
                                fieldToPartialMatchSet,
                                criteria.Field_Two__c,
                                '%' + partialFieldValue.trim().toLowerCase() + '%'
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

    protected Boolean isFieldChanged(String newValue, String oldValue) {
        return oldValue == null ||
            (newValue != null && !newValue.trim().equalsIgnoreCase(oldValue.trim().toLowerCase()));
    }

    protected String extractPartialValue(String value, String startFrom, String endAt) {
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