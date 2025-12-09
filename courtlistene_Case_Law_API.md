# Case Law APIs – CourtListener.com

#### [Back to API Docs](/help/api/rest/v4)[](#back-to-api-docs)

#### [Back to API Docs](/help/api/rest/v4)[](#back-to-api-docs-1)

### Table of Contents[](#table-of-contents)

-   [Overview](#about)
-   [The APIs](#apis)

-   [Dockets](#docket-endpoint)
-   [Clusters](#cluster-endpoint)
-   [Opinions](#opinion-endpoint)
-   [Courts](#court-endpoint)

-   [API Examples](#examples)

-   [Filtering by Court](#filtering-court)
-   [Filtering by Docket No.](#filtering-dn)
-   [Making a Custom Corpus](#search)
-   [Finding by URL](#by-url)

# Case Law API[](#about)

Use these APIs to access our huge and growing database of case law.

To learn more about this collection, including the cases it has and how we get new data each day, see [our coverage page on the topic](/help/coverage/opinions/).

This data is organized into a number of objects. An overview of these objects is described in this section, and greater detail is provided for each, below.

The four most important objects in this data set are courts, dockets, clusters, and opinions. Together, these hold most of the information from a single case:

-   `Court` objects hold information about thousands of courts in this country, including their name, abbreviation, founding date, and more. Every docket is joined to a court to indicate where the case was filed.
    
-   `Docket` objects hold metadata about the case like the date it was initiated or terminated, the docket number, and more. Every cluster is joined to a docket.
    
-   `Cluster` objects group together opinions when a panel hears a case and there is more than one decision, such as a dissent, concurrence, etc. Clusters are an abstraction we created. Every opinion is joined to a cluster.
    
-   `Opinion` objects contain the text of the decision and the metadata related to the individual panel member that wrote it.
    

Putting this all together, dockets are filed in particular courts and contain clusters of opinions.

If you are looking for a particular piece of metadata, you will find it at the lowest object from the list above where it would not be repeated in the database.

For example, you _could_ make the docket number a field of the opinion object. This would be fine until you had more than one opinion in a cluster, or more than one cluster joined to a docket. When that happened, you would wind up repeating the docket number value in each opinion object. Instead, if you make it a field of the docket object, you only have to save it to one place: The docket that binds together the clusters and opinions.

Another example is the opinion text. You _could_ make it a field of the cluster, say, but, again, that wouldn't work, since it wouldn't be clear which opinion the text was a part of in a case with a dissent, concurrence, and majority opinion.

There are two other objects in the case law database:

-   **Citation** objects link together which opinion objects cite each other. For more information, see [their help page](/help/api/rest/citations/).
    
-   **Parenthetical** objects are extracted from the opinion text when a decision explains a citation it relies on as authority. These are not [yet](https://github.com/freelawproject/courtlistener/issues/4082) available in an API, but are available as bulk data.
    

## The APIs[](#apis)

### Dockets — `/api/rest/v4/dockets/`[](#docket-endpoint)

`Docket` objects sit at the top of the object hierarchy. In our PACER database, dockets link together docket entries, parties, and attorneys.

In our case law database, dockets sit above `Opinion Clusters`. In our oral argument database, they sit above `Audio` objects.

To look up field descriptions or options for filtering, ordering, or rendering, complete an HTTP `OPTIONS` request:

curl -v \\
  -X OPTIONS \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/dockets/"

To look up a particular docket, use its ID:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/dockets/4214664/"

The response you get will not list the docket entries, parties, or attorneys for the docket (doing so doesn't scale), but will have many other metadata fields:

{
  "resource\_uri": "https://www.courtlistener.com/api/rest/v4/dockets/4214664/",
  "id": 4214664,
  "court": "https://www.courtlistener.com/api/rest/v4/courts/dcd/",
  "court\_id": "dcd",
  "original\_court\_info": null,
  "idb\_data": null,
  "bankruptcy\_information": null,
  "clusters": \[\],
  "audio\_files": \[\],
  "assigned\_to": "https://www.courtlistener.com/api/rest/v4/people/1124/",
  "referred\_to": null,
  "absolute\_url": "/docket/4214664/national-veterans-legal-services-program-v-united-states/",
  "date\_created": "2016-08-20T07:25:37.448945-07:00",
  "date\_modified": "2024-05-20T03:59:23.387426-07:00",
  "source": 9,
  "appeal\_from\_str": "",
  "assigned\_to\_str": "Paul L. Friedman",
  "referred\_to\_str": "",
  "panel\_str": "",
  "date\_last\_index": "2024-05-20T03:59:23.387429-07:00",
  "date\_cert\_granted": null,
  "date\_cert\_denied": null,
  "date\_argued": null,
  "date\_reargued": null,
  "date\_reargument\_denied": null,
  "date\_filed": "2016-04-21",
  "date\_terminated": null,
  "date\_last\_filing": "2024-05-15",
  "case\_name\_short": "",
  "case\_name": "NATIONAL VETERANS LEGAL SERVICES PROGRAM v. United States",
  "case\_name\_full": "",
  "slug": "national-veterans-legal-services-program-v-united-states",
  "docket\_number": "1:16-cv-00745",
  "docket\_number\_core": "1600745",
  "pacer\_case\_id": "178502",
  "cause": "28:1346 Tort Claim",
  "nature\_of\_suit": "Other Statutory Actions",
  "jury\_demand": "None",
  "jurisdiction\_type": "U.S. Government Defendant",
  "appellate\_fee\_status": "",
  "appellate\_case\_type\_information": "",
  "mdl\_status": "",
  "filepath\_ia": "https://www.archive.org/download/gov.uscourts.dcd.178502/gov.uscourts.dcd.178502.docket.xml",
  "filepath\_ia\_json": "https://archive.org/download/gov.uscourts.dcd.178502/gov.uscourts.dcd.178502.docket.json",
  "ia\_upload\_failure\_count": null,
  "ia\_needs\_upload": true,
  "ia\_date\_first\_change": "2018-09-30T00:00:00-07:00",
  "date\_blocked": null,
  "blocked": false,
  "appeal\_from": null,
  "tags": \[
    "https://www.courtlistener.com/api/rest/v4/tag/1316/"
  \],
  "panel": \[\]
}

The name of a docket can change in response to the outside world, but the names of clusters do not change. Therefore, we have `case_name` fields on both the docket and the cluster.

For example, a suit filed against the EPA administrator might be captioned _Petroleum Co. v. Regan_. That would go into the case name fields of the docket and any decisions that were issued. But if the administrator resigns before the case is resolved, the docket would get a new case name, _Petroleum Co. v. New Administrator_, while the case name fields on the clusters would not change.

For more information on case names, see the [help article on this topic](/help/api/rest/fields/#case-names).

### Clusters — `/api/rest/v4/clusters/`[](#cluster-endpoint)

This is a major API that provides the millions of `Opinion Clusters` that are available on CourtListener.

As with all other APIs, you can look up the field descriptions, filtering, ordering, and rendering options by making an `OPTIONS` request:

curl -v \\
  -X OPTIONS \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/clusters/"

A few notes:

-   The `id` field of the cluster is used in case law URLs on CourtListener.
    
-   The `sub_opinions` field provides a list of the opinions that are linked to each cluster.
    
-   The `citations` field will contain a list of parallel citations for the cluster. See the [citation API](/help/api/rest/citations/) for details.
    
-   There are several fields with judge information, such as `judges`, `panel`, `non_participating_judges`, etc. Some of these fields contain strings and others are linked to records in our [judge API](/help/api/rest/judges/). When we are able to normalize a judge's name into a record in the judge database, we do so. If not, we store their name in a string field for later normalization.
    

### Opinions — `/api/rest/v4/opinions/`[](#opinion-endpoint)

This API contains the text and other metadata about specific decisions.

As with all other APIs, you can look up the field descriptions, filtering, ordering, and rendering options by making an `OPTIONS` request:

**Listen Up:** When retrieving opinion text, prefer the `html_with_citations` field instead of `plain_text`. The `html_with_citations` field contains the raw text of the decision, and is the most reliable field for most purposes.  
  
Opinion URLs on the CourtListener website contain a `cluster_id`, not an `opinion_id`. If you want to look up a case using that ID, query the Cluster API. See [Finding a Case by URL](#by-url), below.

curl -v \\
  -X OPTIONS \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/opinions/"

A few notes:

-   The `type` field indicates whether the item is a concurrence, lead opinion, dissent, etc. The values provided for this field are proceeded by numbers so that if they are sorted, they will also be sorted from highest priority to lowest. The most common type of opinion is a "Combined Opinion" this is what we label any opinion that either cannot be identified as a specific type, or that contains more than one type.
    
-   The `download_url` field contains the original location where we scraped the decision. Many courts do not maintain [Cool URIs](https://www.w3.org/Provider/Style/URI.html), so this field is often unreliable.
    
-   The `local_path` field contains the path to the binary file for the decision, if we have one. To use it, see the [help article on this topic](/help/api/rest/fields/#downloads).
    
-   The `opinions_cited` field has a list of other opinions cited by the one you are reviewing.
    
-   The `ordering_key` field indicates the order of opinions within a cluster. This field is only populated for opinions ingested from Harvard or Columbia sources.
    
-   In general, the best field for the text of a decision is `html_with_citations`, in which each citation has been identified and linked. This is the field that is used in the CourtListener website.
    
    The following fields are used to generate `html_with_citations`, but are not usually recommended:
    
    -   `html_columbia` will be populated if we got the content from the Columbia collaboration.
    -   `html_lawbox` will be populated if we got the content from the Lawbox donation.
    -   `xml_harvard` will be populated if the source was Harvard's Caselaw Access Project. This field has a lot of data but is not always perfect due to being created by OCR.
    -   `html_anon_2020` will be populated if we got the content from our anonymous source in 2020.
    -   `html` will be populated if we got the opinion from a court's website as a Word Perfect or HTML document, or if we got the opinion from Resource.org, which provided HTML documents.
    -   `plain_text` will be populated if we got the opinion from a court's website as a PDF or Microsoft Word document.
    
    Whichever field you choose, please use [Field Selection](/help/api/rest/v4#field-selection) to omit unnecessary fields. This will make your system faster and ease the load on ours.
    

### Courts — `/api/rest/v4/courts/`[](#court-endpoint)

This API contains data about the courts we have in our database, and is joined into nearly every other API so that you can know where an event happened, a judge worked, etc.

To look up field descriptions or options for filtering, ordering, or rendering, complete an HTTP `OPTIONS` request.

You can generally cache this API. It does not change often.

## API Examples[](#examples)

### Filtering to Opinions in a Court[](#filtering-court)

Opinions are joined to clusters, which join to dockets, and finally to courts. Therefore, one way to get opinions in a specific court is to use a filter like `cluster__docket__court=XYZ` (note the use of double underscores):

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/opinions/?cluster\_\_docket\_\_court=scotus"

That returns:

{
  "next": "https://www.courtlistener.com/api/rest/v4/opinions/?cluster\_\_docket\_\_court=scotus&cursor=cD0xMDUxNjI5NA%3D%3D",
  "previous": null,
  "results": \[
      {
          "resource\_uri": "https://www.courtlistener.com/api/rest/v4/opinions/9973155/",
          "id": 9973155,
  ...

Such an approach is fine if all you want is the opinion object, but often you'll want the docket and the cluster too.

In that case, start by getting the dockets with a filter like `court=XYZ`, then use the IDs in those dockets to get clusters and opinions.

For example, this gets the dockets from SCOTUS:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/dockets/?court=scotus"

The first result contains a `clusters` key like:

"clusters": \[
    "https://www.courtlistener.com/api/rest/v4/clusters/9502621/"
\],

So we can simply get that URL:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/clusters/9502621/"

That returns a cluster, which has the following keys:

"docket": "https://www.courtlistener.com/api/rest/v4/dockets/68533094/",
"sub\_opinions": \[
    "https://www.courtlistener.com/api/rest/v4/opinions/9969234/"
\],

Finally, GET the links in the `sub_opinions` field to have the complete object:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/opinions/9969234/"

### Filtering by Docket Number[](#filtering-dn)

If you know a docket number, you can use it to look up a docket, cluster, or opinion:

A docket by docket number:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/dockets/?docket\_number=23A994"

A cluster by docket number:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/clusters/?docket\_\_docket\_number=23A994"

An opinion by docket number:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/opinions/?cluster\_\_docket\_\_docket\_number=23A994"

Docket numbers are not unique, so you'll want to add a court filter too:

-   For dockets, add: `&court=scotus`
-   For clusters, add: `&docket__court=scotus`
-   For opinions, add: `&cluster__docket__court=scotus`

You may also find the [search API](/help/api/rest/search/) helpful, since it will do fuzzy docket searches.

### Making a Custom Case Law Corpus[](#search)

A common need by empirical researchers is a collection of case law about a particular topic. To build such a corpus, use the [search API](/help/api/rest/search/) to identify cases and use these APIs to download them.

### Finding a Case by URL[](#by-url)

If you know the URL of a case, you can find it in the cluster API. For example, _Obergefell v. Hodges_ has this URL, with cluster ID `2812209`:

https://www.courtlistener.com/opinion/2812209/obergefell-v-hodges/

This case can be found in the cluster API using that same ID:

curl -v \\
  --header 'Authorization: Token fae798300faf78c7cc366ea007310d4257c0d9d4' \\
  "https://www.courtlistener.com/api/rest/v4/clusters/2812209/"

Opinion IDs do not reliably match cluster IDs.

## Please Support Open Legal Data[](#please-support-open-legal data)

These services are sponsored by [Free Law Project](https://free.law) and users like you. We provide these services in furtherance of our mission to make the legal sector more innovative and equitable.

We have provided these services for over a decade, and we need your contributions to continue curating and enhancing them.

Will you support us today by becoming a member?

[Join FLP](https://donate.free.law/forms/membership)