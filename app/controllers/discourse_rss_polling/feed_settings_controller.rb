# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < Admin::AdminController
    requires_plugin 'discourse-rss-polling'

    def show
      render json: FeedSettingFinder.all
    end

    def update

      if params[:feed_settings] == []
        new_feed_settings = []
      else
        new_feed_settings = (feed_setting_params.presence || []).map do |feed_setting|
          feed_setting.values_at(:feed_url, :author_username, :start_date)
        end
      end

      SiteSetting.rss_polling_feed_setting = new_feed_settings.to_yaml

      render json: FeedSettingFinder.all
    end
    
    def refresh
      feed_url = params[:feed_url]
      feed = DiscourseRssPolling::FeedSettingFinder.by_embed_url(feed_url)
      
      if feed && feed.poll(force: true)
        render json: success_json
      else
        render json: failed_json
      end
    end

    private

    def feed_setting_params
      params.require(:feed_settings)
    end
  end
end
