# frozen_string_literal: true

# name: discourse-topic-query
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0
# transpile_js: true

enabled_site_setting :discourse_in_post_topic_list_enabled

after_initialize do
  module ::DiscourseTopicQuery
    PLUGIN_NAME ||= "discourse-topic-query"
    HAS_TOPIC_QUERY ||= :has_topic_query
    VALID_ATTRIBUTES ||= {
      'tags' => { type: :array },
      'topicids' => { type: :array, mapping: :topic_ids },
      'excepttopicids' => { type: :array, mapping: :except_topic_ids },
      'ascending' => { type: :string },
      'order' => { type: :string },
      'status' => { type: :string },
    }

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTopicQuery
    end

    class Error < StandardError; end

    def self.rebake_posts_with_topic_query
      PostCustomField.joins(:post).where(name: HAS_TOPIC_QUERY).find_each do |pcf|
        if !pcf.post
          pcf.destroy!
        else
          pcf.post.rebake!
        end
      end
    end
  end

  register_post_custom_field_type(DiscourseTopicQuery::HAS_TOPIC_QUERY, :boolean)

  on(:before_post_process_cooked) do |doc, post|
    topic_queries = doc.css('.discourse-topic-query')
    topic_queries.each do |topic_list|
      options = {}
      DiscourseTopicQuery::VALID_ATTRIBUTES.each do |attribute, params|
        value = topic_list.attributes["data-#{attribute}"]&.value
        attribute = params[:mapping] || attribute.to_sym
        if value
          case params[:type]
          when :array
            options[attribute] = value.split(",")
          when :string
            options[attribute] = value
          end
        end
      end

      topics_list = []
      query = TopicQuery.new(post.user, options)
      query.latest_results.each do |topic|
        topics_list << "<li><a href=\"#{topic.url}\">#{topic.title}</a></li>"
      end

      if topics_list.count > 0
        topic_list.inner_html = "<ul>" + topics_list.join + "</ul>"
      end
    end

    if topic_queries.empty?
      if post.custom_fields[DiscourseTopicQuery::HAS_TOPIC_QUERY]
        PostCustomField
          .where(post_id: post.id, name: DiscourseTopicQuery::HAS_TOPIC_QUERY)
          .delete_all
      end
    else
      if !post.custom_fields[DiscourseTopicQuery::HAS_TOPIC_QUERY]
        post.upsert_custom_fields(DiscourseTopicQuery::HAS_TOPIC_QUERY => true)
      end
    end
  end
end
