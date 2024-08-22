# Lead Account Matcher 

## Overview

The Lead Account Matcher is a customizable Salesforce solution designed to automate the process of matching Leads with existing Accounts based on configurable matching criteria. This solution uses Salesforce Custom Metadata Types (Matching Criteria) to allow flexible matching logic and provides a foundation for future expansion to other objects.

The core functionality is achieved through the abstract MatcherService class, which can be extended to create specific matchers for various Salesforce objects. In this implementation, we provide a LeadAccountMatcher to match Leads to Accounts based on specific fields, such as Company Name or Website.

## Components

1. MatcherService (Apex Class): Abstract class defining the matching framework.
2. LeadAccountMatcher (Apex Class): Concrete implementation of MatcherService that matches Leads to Accounts.
3. MatchingCriteria__mdt (Custom Metadata Type): Used to configure matching rules and priorities.

## Matching Criteria Custom Metadata Configuration
The MatchingCriteria__mdt custom metadata type stores the matching rules. Below is a description of each field:
- Field_One__c (Text): The field to be compared (e.g., Company).
- Field_Two__c (Text): The field to match against (e.g., Name).
- Match_Type__c (Picklist): Defines the type of matching:
    - Exact: Matches based on exact field value.
    - Partial: Matches based on partial field values
- Partial_Field_One_Start__c (Text): The starting substring to use for partial matching (optional).
- Partial_Field_One_End__c (Text): The ending substring to use for partial matching (optional).
- Partial_Field_Two_Start__c (Text): The starting substring to use for partial matching (optional).
- Partial_Field_Two_End__c (Text): The ending substring to use for partial matching (optional).
- Priority__c (Number): Priority of the matching rule, where lower numbers indicate higher priority.
- Active__c (Checkbox): Flag to indicate if this matching criteria is active.
- Matching_Object__c (Text): The target object that the matching criteria apply to (e.g., Account for Lead-Account matching).


## Deploying To A Salesforce Org
## Prerequisites
Before deploying code to a Salesforce org from GitHub, make sure you have the following:

**Salesforce CLI (SFDX)**:
   - Install from the official website: [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli).

**Git**:
   - Ensure that Git is installed. You can install it from [Git's official site](https://git-scm.com/).


**Salesforce Developer Org**:
   - A Salesforce Developer Org where you can deploy the code.

## Clone this repository
**Clone the Repository**:
   - Open a terminal/command prompt.
   - Navigate to the directory where you want to store the repository.
   - Run the following command to clone the GitHub repository:

   ```bash
   git clone git@github.com:MikeReal116/record-matching.git 
   ```
   - Navigate to the project directory
   - Authenticate with Salesforce Org:
   ```bash
   sf org login web
   ````
- Deploy the metadate to Salesforce
```bash
sf project deploy start
 ```
 
    

   