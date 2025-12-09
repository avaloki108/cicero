# Api Root – Django REST framework

[GET](/api/rest/v4/)

-   [json](/api/rest/v4/?format=json)
-   [api](/api/rest/v4/?format=api)
-   [xml](/api/rest/v4/?format=xml)

OPTIONS

# Api Root

The default basic root view for DefaultRouter

**GET** /api/rest/v4/

**HTTP 200 OK**
**Allow:** GET, HEAD, OPTIONS
**Content-Type:** application/json
**Vary:** Accept

{
    "search": "[https://www.courtlistener.com/api/rest/v4/search/](https://www.courtlistener.com/api/rest/v4/search/)",
    "dockets": "[https://www.courtlistener.com/api/rest/v4/dockets/](https://www.courtlistener.com/api/rest/v4/dockets/)",
    "bankruptcy-information": "[https://www.courtlistener.com/api/rest/v4/bankruptcy-information/](https://www.courtlistener.com/api/rest/v4/bankruptcy-information/)",
    "originating-court-information": "[https://www.courtlistener.com/api/rest/v4/originating-court-information/](https://www.courtlistener.com/api/rest/v4/originating-court-information/)",
    "docket-entries": "[https://www.courtlistener.com/api/rest/v4/docket-entries/](https://www.courtlistener.com/api/rest/v4/docket-entries/)",
    "recap-documents": "[https://www.courtlistener.com/api/rest/v4/recap-documents/](https://www.courtlistener.com/api/rest/v4/recap-documents/)",
    "courts": "[https://www.courtlistener.com/api/rest/v4/courts/](https://www.courtlistener.com/api/rest/v4/courts/)",
    "audio": "[https://www.courtlistener.com/api/rest/v4/audio/](https://www.courtlistener.com/api/rest/v4/audio/)",
    "clusters": "[https://www.courtlistener.com/api/rest/v4/clusters/](https://www.courtlistener.com/api/rest/v4/clusters/)",
    "opinions": "[https://www.courtlistener.com/api/rest/v4/opinions/](https://www.courtlistener.com/api/rest/v4/opinions/)",
    "opinions-cited": "[https://www.courtlistener.com/api/rest/v4/opinions-cited/](https://www.courtlistener.com/api/rest/v4/opinions-cited/)",
    "tag": "[https://www.courtlistener.com/api/rest/v4/tag/](https://www.courtlistener.com/api/rest/v4/tag/)",
    "people": "[https://www.courtlistener.com/api/rest/v4/people/](https://www.courtlistener.com/api/rest/v4/people/)",
    "disclosure-typeahead": "[https://www.courtlistener.com/api/rest/v4/disclosure-typeahead/](https://www.courtlistener.com/api/rest/v4/disclosure-typeahead/)",
    "positions": "[https://www.courtlistener.com/api/rest/v4/positions/](https://www.courtlistener.com/api/rest/v4/positions/)",
    "retention-events": "[https://www.courtlistener.com/api/rest/v4/retention-events/](https://www.courtlistener.com/api/rest/v4/retention-events/)",
    "educations": "[https://www.courtlistener.com/api/rest/v4/educations/](https://www.courtlistener.com/api/rest/v4/educations/)",
    "schools": "[https://www.courtlistener.com/api/rest/v4/schools/](https://www.courtlistener.com/api/rest/v4/schools/)",
    "political-affiliations": "[https://www.courtlistener.com/api/rest/v4/political-affiliations/](https://www.courtlistener.com/api/rest/v4/political-affiliations/)",
    "sources": "[https://www.courtlistener.com/api/rest/v4/sources/](https://www.courtlistener.com/api/rest/v4/sources/)",
    "aba-ratings": "[https://www.courtlistener.com/api/rest/v4/aba-ratings/](https://www.courtlistener.com/api/rest/v4/aba-ratings/)",
    "parties": "[https://www.courtlistener.com/api/rest/v4/parties/](https://www.courtlistener.com/api/rest/v4/parties/)",
    "attorneys": "[https://www.courtlistener.com/api/rest/v4/attorneys/](https://www.courtlistener.com/api/rest/v4/attorneys/)",
    "recap": "[https://www.courtlistener.com/api/rest/v4/recap/](https://www.courtlistener.com/api/rest/v4/recap/)",
    "recap-email": "[https://www.courtlistener.com/api/rest/v4/recap-email/](https://www.courtlistener.com/api/rest/v4/recap-email/)",
    "recap-fetch": "[https://www.courtlistener.com/api/rest/v4/recap-fetch/](https://www.courtlistener.com/api/rest/v4/recap-fetch/)",
    "recap-query": "[https://www.courtlistener.com/api/rest/v4/recap-query/](https://www.courtlistener.com/api/rest/v4/recap-query/)",
    "fjc-integrated-database": "[https://www.courtlistener.com/api/rest/v4/fjc-integrated-database/](https://www.courtlistener.com/api/rest/v4/fjc-integrated-database/)",
    "tags": "[https://www.courtlistener.com/api/rest/v4/tags/](https://www.courtlistener.com/api/rest/v4/tags/)",
    "docket-tags": "[https://www.courtlistener.com/api/rest/v4/docket-tags/](https://www.courtlistener.com/api/rest/v4/docket-tags/)",
    "prayers": "[https://www.courtlistener.com/api/rest/v4/prayers/](https://www.courtlistener.com/api/rest/v4/prayers/)",
    "increment-event": "[https://www.courtlistener.com/api/rest/v4/increment-event/](https://www.courtlistener.com/api/rest/v4/increment-event/)",
    "visualizations/json": "[https://www.courtlistener.com/api/rest/v4/visualizations/json/](https://www.courtlistener.com/api/rest/v4/visualizations/json/)",
    "visualizations": "[https://www.courtlistener.com/api/rest/v4/visualizations/](https://www.courtlistener.com/api/rest/v4/visualizations/)",
    "agreements": "[https://www.courtlistener.com/api/rest/v4/agreements/](https://www.courtlistener.com/api/rest/v4/agreements/)",
    "debts": "[https://www.courtlistener.com/api/rest/v4/debts/](https://www.courtlistener.com/api/rest/v4/debts/)",
    "financial-disclosures": "[https://www.courtlistener.com/api/rest/v4/financial-disclosures/](https://www.courtlistener.com/api/rest/v4/financial-disclosures/)",
    "gifts": "[https://www.courtlistener.com/api/rest/v4/gifts/](https://www.courtlistener.com/api/rest/v4/gifts/)",
    "investments": "[https://www.courtlistener.com/api/rest/v4/investments/](https://www.courtlistener.com/api/rest/v4/investments/)",
    "non-investment-incomes": "[https://www.courtlistener.com/api/rest/v4/non-investment-incomes/](https://www.courtlistener.com/api/rest/v4/non-investment-incomes/)",
    "disclosure-positions": "[https://www.courtlistener.com/api/rest/v4/disclosure-positions/](https://www.courtlistener.com/api/rest/v4/disclosure-positions/)",
    "reimbursements": "[https://www.courtlistener.com/api/rest/v4/reimbursements/](https://www.courtlistener.com/api/rest/v4/reimbursements/)",
    "spouse-incomes": "[https://www.courtlistener.com/api/rest/v4/spouse-incomes/](https://www.courtlistener.com/api/rest/v4/spouse-incomes/)",
    "alerts": "[https://www.courtlistener.com/api/rest/v4/alerts/](https://www.courtlistener.com/api/rest/v4/alerts/)",
    "docket-alerts": "[https://www.courtlistener.com/api/rest/v4/docket-alerts/](https://www.courtlistener.com/api/rest/v4/docket-alerts/)",
    "memberships": "[https://www.courtlistener.com/api/rest/v4/memberships/](https://www.courtlistener.com/api/rest/v4/memberships/)",
    "citation-lookup": "[https://www.courtlistener.com/api/rest/v4/citation-lookup/](https://www.courtlistener.com/api/rest/v4/citation-lookup/)"
}