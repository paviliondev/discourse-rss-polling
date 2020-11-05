## RStudio RSS Polling

This is a fork of the [Discourse RSS Polling plugin](https://github.com/paviliondev/rstudio-rss-polling), with modifications

### Modifications

#### Feed start date

When this is set, feed items with a ``pubDate`` prior to the date will be filtered out and not processed upon import.

#### Saves additional data

This plugin will save the following additional data

- Feed item full text, if present, will be added to the first post
- The following "new topic form" data will be set:
   - image_url:  The link preview image from the first onebox
   - posted_at: The ``pubDate`` of the feed item
   - description: Excerpt of the full text of the feed item
   
New topic form data is used by the [New Topic Form Plugin](https://github.com/paviliondev/discourse-new-topic-form) and [RStudio Composer Template Plugin](https://github.com/paviliondev/discourse-rstudio-composer-template-plugin), and presented in the topic list and composer.

#### Does not update existing feed topics

The plugin does not update existing topics created from rss feed items. This is to allow site admins to edit imported content and for those edits to be retained.





