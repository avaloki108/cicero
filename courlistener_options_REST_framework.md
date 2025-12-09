# Api Root – Django REST framework

[GET](/api/rest/v4/)

-   [json](/api/rest/v4/?format=json)
-   [api](/api/rest/v4/?format=api)
-   [xml](/api/rest/v4/?format=xml)

OPTIONS

# Api Root

The default basic root view for DefaultRouter

**OPTIONS** /api/rest/v4/

**HTTP 200 OK**
**Allow:** GET, HEAD, OPTIONS
**Content-Type:** application/json
**Vary:** Accept

{
    "name": "Api Root",
    "description": "The default basic root view for DefaultRouter",
    "renders": \[
        "application/json",
        "text/html",
        "application/xml"
    \],
    "parses": \[
        "application/json",
        "application/x-www-form-urlencoded",
        "multipart/form-data",
        "application/xml"
    \]
}