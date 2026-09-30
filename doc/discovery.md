# Discovery and adoption delivery — September 30, 2026

This document records the current evidence, prepared changes and the external
steps required to make them public. It does not report an achieved ranking or
download increase. Research included official documentation, a current Google
blog announcement and Flutter community discussions.

## Observed baseline

Public HTTP reads on September 30, 2026:

| Measure | Observation | Source |
| --- | --- | --- |
| Published version | 0.4.3 | [Package API](https://pub.dev/api/packages/cupertino_fundations_models) |
| Downloads | 290 in the rolling last 30 days | [Metrics API](https://pub.dev/api/packages/cupertino_fundations_models/metrics) |
| Pub points | 160/160 | Same metrics API, aggregate and versioned Pana result |
| pub.dev likes | 0 | Same metrics API |
| GitHub stars | 1 | [Public repository API](https://api.github.com/repos/sooyvilla/cupertino_fundations_models) |
| Repository description, topics, homepage | Empty | Same repository API |
| GitHub Pages | `has_pages: false`; proposed site URL returns 404 | Same repository API and public HTTP read |
| Root host robots | `https://sooyvilla.github.io/robots.txt` returns 404 | Public HTTP read; no root policy configured by this task |

The first default pub.dev API result page placed this package eighth for
`apple foundation models`. It did not appear among the first ten results for
`local ai`, `ios ai` or `on device ai`. These are dated snapshots of unfiltered
queries, not stable rankings or a claim about every user's search results.
Repeat with the same queries and parameters when comparing a later release.

## What the research changes

Pub.dev weighs matching package name, description, README and API text, then
download/like counts and pub points. Its weighting can change. The identifier
must remain compatible, so the useful editable surfaces are description,
README and relevant topics. Arbitrary YAML SEO fields are ignored. Keep five
topics: `apple-intelligence`, `foundation-models`, `on-device-ai`, `ai`, `ios`.
Speech remains in the description and guides. See
[pub.dev search](https://pub.dev/help/search) and
[pubspec topics and description](https://dart.dev/tools/pub/pubspec).

Google's current guidance prioritizes useful, crawlable, indexed content for
both conventional and generative search. It explicitly says Google does not
use `llms.txt` for ranking; manufactured mentions and keyword variations are
not a shortcut. The site therefore provides real integration guides and
constraints, with HTML available without client JavaScript. `llms.txt` is an
optional reference index for other consumers. See
[Google's AI search guidance](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
and the [llms.txt proposal](https://llmstxt.org/).

OpenAI documents `OAI-SearchBot` as its search crawler and separates it from
`GPTBot` training controls. Permitting search crawling is an eligibility step,
not a guaranteed mention. Perplexity similarly documents its search crawler.
See [OpenAI crawlers](https://developers.openai.com/api/docs/bots) and
[Perplexity crawlers](https://docs.perplexity.ai/docs/resources/perplexity-crawlers).

The current [Google Search Console blog announcement](https://developers.google.com/search/blog/2026/06/gen-ai-performance-reports)
describes reports for visibility within generative search features. Use
account-observed reports after ownership is verified; this task did not access
Search Console or establish current account metrics.

The [Flutter discussion of another Foundation Models plugin](https://www.reddit.com/r/FlutterDev/comments/1w5g83f/apples_ondevice_llm_from_flutter_streaming_tool/)
shows a developer asking why another bridge is needed among existing packages.
An [earlier Foundation Models discussion](https://www.reddit.com/r/FlutterDev/comments/1ocyykz/apples_new_foundation_models_apis_in_flutter/)
includes concerns about model output and domain knowledge. These are audience
signals, not technical contracts or proof of a promotion channel's conversion.
Our response is concrete recipes, lifecycle/privacy contracts, a comparison
of approaches and honest unsupported-feature boundaries.

## Prepared repository changes

- Search-relevant English package description within Dart's recommended size,
  an iOS topic, explicit Flutter/native/local positioning and dynamic pub badges.
- English and Spanish first-response tutorials with equivalent scope,
  availability checks, cleanup and error handling.
- Structured extraction/classification recipes, FAQ and architecture comparison.
- A Jekyll documentation site in `doc/site/`, generated from shared Markdown
  sources by a manual GitHub Pages workflow. No plugin runtime dependency added.
- Per-page titles, descriptions, canonical URLs, HTML language, reciprocal
  tutorial hreflang, Open Graph/Twitter metadata and a navigation-derived sitemap.
- `SoftwareSourceCode`, `WebSite` and `WebPage` JSON-LD using real source/package
  URLs and version. No fabricated reviews, ratings, testimonials or rich-result promise.
- Markdown alternatives, agent guide and optional documentation indexes.
- [Reviewable GitHub metadata](repository-metadata.json) and
  [promotion drafts](promotion.md); nothing sent to a community or another person.

The site, workflow and internal promotion/research files are excluded from the
pub archive. The public tutorials, FAQ, recipes and selection guide are included.
No screenshot is advertised: no app capture or runtime demonstration was requested.

## Publication completed

On September 30 the owner approved the Git delivery, repository metadata,
documentation site and 0.4.4 publication, provided the writing is natural,
current and easy to understand. The README, tutorials, FAQ and landing page
received that editorial pass. Community posts remain drafts.

The documentation went live before the package links changed, keeping all
public URLs reachable during the delivery. The final patch synchronizes
pubspec, podspec, the diagnostic version string, the example's path lock entry
and current documentation references. Historical notes and migration titles
remain intact.

The manual Pages workflow publishes shared Markdown and then notifies
IndexNow about the sitemap URLs. It does not build or run the Flutter app.
The package homepage links to the live site, documentation links to `/usage/`,
and repository/issues continue to point to GitHub. Pub.dev accepted 0.4.4
with its integrated publication checks.

GitHub's reference workflow is documented in
[custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
[GitHub topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
provide an additional repository-discovery surface.

The optional promotion-directory route is not universally available:
[Awesome Flutter's current rules](https://github.com/Solido/awesome-flutter/blob/master/contributing.md)
require at least 35 stars. With the observed 1 star, this package is not yet
eligible. No submission was made or acceptance badge added.

## Crawling and ownership after deployment

A `robots.txt` applies at the **host root**, not a project subdirectory. Creating
`/cupertino_fundations_models/robots.txt` would not configure the crawler policy
for `sooyvilla.github.io`; this task intentionally does not present such a file
as effective. The current root returned 404. With a controlled root site or
custom domain, review the effective policy and any firewall, then allow search
crawlers for the documentation. Search and training controls are independent.
See [Google robots.txt placement](https://developers.google.com/search/docs/crawling-indexing/robots/create-robots-txt).

Do not modify a separate root-site repository or purchase a domain without the
corresponding authorization. A custom domain is optional, not a prerequisite
for the prepared GitHub Pages site.

Search Console ownership and Bing Webmaster ownership require the owner's
account. The layout accepts the public verification tokens through optional
`search_console_verification` and `bing_verification` config values, but none
is invented. After verification, submit the actual live `/sitemap.xml` and
request indexing of the key tutorials. See
[Google ownership verification](https://support.google.com/webmasters/answer/9008080)
and [sitemap submission](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap).
An [IndexNow](https://www.indexnow.org/documentation) key is an optional additional
submission mechanism for participating engines; it is not Google indexing and
is configured for this project subpath using a publicly hosted verification file.
The manual Pages workflow submits its sitemap URLs after deployment. Its HTTP
receipt must be recorded separately from actual indexing.

Pub.dev publisher verification requires a domain and control of its Google
Search Console property. No publisher domain was supplied, so a badge cannot
be created honestly. See [verified publishers](https://dart.dev/tools/pub/verified-publishers).

## Adoption measurement

The baseline is **290 rolling-30-day downloads**, not 290 unique developers or
apps. Download count may include dependency-resolution/CI activity. A literal
5,000% increase from that baseline would be 14,790 downloads in the same window;
this is an aspiration, not a result or forecast.

After publication, record weekly snapshots of rolling downloads, likes and
GitHub stars, alongside Search Console impressions/clicks and available AI
visibility reports. Compare equal windows and annotate release/promotion dates.
Search positions are diagnostic observations, not the sole success measure.

Use a small dated set of evaluation queries: `Flutter iOS local AI`,
`Apple Foundation Models Flutter`, `offline LLM iPhone Flutter`,
`librería Flutter iOS inteligencia artificial local`, and `Flutter structured
JSON Apple Intelligence`. For assistant answers, record tool/model/date/locale
and actual citations. Do not turn one response into a claim that all AIs recommend
the package. Citation and conversion evidence, not file presence, establishes impact.

When impressions are weak, revisit indexing and relevance. When impressions
grow but installs do not, improve the integration guide using real issue reports.
When installs grow, investigate repeated adoption blockers before expanding
promotion. No recurring automation or telemetry was installed by this task.

## Delivery evidence and limits

Release commit `2cdb0b72a18ec940b10eaaeaf555ba23e765b03d` is on `origin/main`.
[The release documentation run](https://github.com/sooyvilla/cupertino_fundations_models/actions/runs/36761417993)
completed successfully, including the IndexNow step. The homepage, all 15 guide
routes, sitemap, llms.txt and both tutorial Markdown files returned HTTP 200.
The live HTML contains canonical URLs, reciprocal English/Spanish links and
source-code structured data. Repository description, 15 topics and homepage
were applied and read back.

Pub.dev accepted **0.4.4** at `2026-09-30T18:50:22.013609Z`.
[The package API](https://pub.dev/api/packages/cupertino_fundations_models)
confirms the latest version, site URLs, updated description and iOS topic.
The served archive SHA256 is
`dc493a986980ac9126cb431989bf0950566472e72d9a657ced95337197cd79a3`.
Its README and all new public guides are present; internal research, promotion
and site sources are excluded.

IndexNow received **16 URLs with HTTP 202** at `2026-09-30T18:51:05Z`.
That means receipt with key verification pending, not indexing or ranking.
The version-specific pub.dev metric query `?version=0.4.4` completed with
Pana success at `2026-09-30T18:56:31.831763`: **160/160 points**, verified
repository and no URL problems. This is evidence for the new release,
separate from the previously cached 0.4.3 aggregate.

Documentation generation/deployment and Pub's integrated checks were part of
the authorized publication. No independent tests, analysis, formatters,
validators, visual checks, Flutter builds, apps, simulators or devices were run.
No messages were posted to communities. The owner authorized Search Console
and Bing setup. Their Codex browser tabs currently require sign-in, so property
registration awaits that authentication. The owner also asked to review each
promotional text before it is sent or published.

No observed download uplift, indexing, search-engine ownership, paid campaign
or assistant recommendation is claimed. The original growth objective remains
open until there is measurable adoption evidence.
