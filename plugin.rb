# frozen_string_literal: true

# name: discourse-rss-polling
# about: This plugin enables support for importing embedded content from multiple RSS/ATOM feeds
# version: 0.0.1
# authors: xrav3nz
# url: https://github.com/discourse/discourse-rss-polling

load File.expand_path(File.join('..', 'lib', 'discourse_rss_polling', 'engine.rb'), __FILE__)

enabled_site_setting :rss_polling_enabled
add_admin_route 'rss_polling.title', 'rss_polling'
register_asset 'stylesheets/rss-polling.scss'
register_svg_icon 'save' if respond_to?(:register_svg_icon)

Discourse::Application.routes.append do
  mount ::DiscourseRssPolling::Engine, at: '/admin/plugins/rss_polling'
end

after_initialize do
  class ::CustomTopicEmbed < ::TopicEmbed
    self.table_name = 'topic_embed'
    
    def self.import(user, topic, contents)
      return unless topic.url =~ /^https?\:\/\//
      
      title = topic.title
      url = normalize_url(topic.url)
      embed = TopicEmbed.find_by("lower(embed_url) = ?", url)
      content_sha1 = Digest::SHA1.hexdigest(contents)
      post = nil
      
      description_length = 300
      description = ExcerptParser.get_excerpt(
        contents,
        description_length,
        strip_links: true,
        strip_images: true,
        text_entities: true
      )
      
      custom_fields = {
        new_topic_form_data: {
          url: topic.url,
          posted_at: topic.created_at,
          description: description
        },
        custom_embed: true
      }

      if embed.blank?
        Topic.transaction do
          eh = EmbeddableHost.record_for_url(url)
          
          create_args = {
            title: title,
            raw: self.build_raw(url, contents),
            category: eh.try(:category_id),
            featured_link: url,
            import_mode: true,
            skip_jobs: true,
            topic_opts: {
              custom_fields: custom_fields
            }
          }
          
          creator = PostCreator.new(user, create_args)
          post = creator.create
          
          if post.present?
            
            TopicEmbed.create!(
              topic_id: post.topic_id,
              embed_url: url,
              content_sha1: content_sha1,
              post_id: post.id
            )
            
            cp = CookedPostProcessor.new(post)
            cp.post_process(new_post: true)
          end
        end
      else
        post = embed.post

        # Update the topic if it changed
        if post&.topic
          if post.user != user
            PostOwnerChanger.new(
              post_ids: [post.id],
              topic_id: post.topic_id,
              new_owner: user,
              acting_user: Discourse.system_user
            ).change_owner!

            # make sure the post returned has the right author
            post.reload
          end

          if (content_sha1 != embed.content_sha1) ||
              (title && title != post&.topic&.title)
            changes = {
              title: title,
              raw: self.build_raw(url, contents),
              topic_opts: {
                custom_fields: custom_fields
              }
            }
            
            post.revise(
              user,
              changes,
              skip_validations: true,
              bypass_rate_limiter: true
            )
            embed.update!(content_sha1: content_sha1)
          end
        end
      end

      post
    end
    
    def self.build_raw(url, contents)
%{
#{url}

<small>#{I18n.t('embed.imported_from', link: "<a href='#{url}'>#{url}</a>")}</small>

<hr>

#{contents}
}
    end
  end
  
  module CustomTopicEmbedTopicExtension
    def has_topic_embed?
      TopicEmbed.where(topic_id: id).exists? && !custom_fields["custom_embed"]
    end
  end
  
  ::Topic.prepend CustomTopicEmbedTopicExtension
  
  on(:post_process_cooked) do |doc, post|
    if post.topic.custom_fields['custom_embed']
      oneboxed_imgs = doc.css(".onebox-body img, .onebox img, img.onebox") - doc.css("img.site-icon")
      
      if oneboxed_imgs.present?
        new_topic_form_data = post.topic.custom_fields['new_topic_form_data'] || {}
        new_topic_form_data['image_url'] = oneboxed_imgs.first['src']
        post.topic.custom_fields['new_topic_form_data'] = new_topic_form_data
        post.topic.save_custom_fields(true)
      end
    end
  end
end
