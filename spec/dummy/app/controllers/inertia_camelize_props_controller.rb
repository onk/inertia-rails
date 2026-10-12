# frozen_string_literal: true

class InertiaCamelizePropsController < ApplicationController
  inertia_config(camelize_props: true)

  inertia_share do
    { current_account: { account_name: 'Acme' } }
  end

  # Two pages of records, so that the second request returns something the first one did not.
  PROFILE_PAGES = [
    [{ profile_id: 1, created_at: '2026-09-20' }],
    [{ profile_id: 2, created_at: '2026-09-21' }]
  ].freeze

  def plain
    render inertia: 'TestComponent', props: {
      user_profiles: [{ profile_id: 1, created_at: '2026-09-21' }],
      current_user: { first_name: 'Jane', _record_id: 1 },
      tag_names: %w[first_tag second_tag],
      posts: [],
    }
  end

  def merged
    render inertia: 'TestComponent', props: {
      chat_messages: InertiaRails.merge { [] },
      new_arrivals: InertiaRails.merge(prepend: true) { [] },
      user_settings: InertiaRails.deep_merge { { color_scheme: 'dark' } },
      blog_posts: InertiaRails.merge(match_on: :post_id) { [{ post_id: 1 }] },
      paged_posts: InertiaRails.merge(append: 'post_list', match_on: 'post_list.post_id') do
        { post_list: [{ post_id: 1 }] }
      end,
    }
  end

  def scrolling
    page = params.fetch(:page, 1).to_i

    render inertia: 'TestComponent', props: {
      user_profiles: InertiaRails.scroll(
        page_name: 'page',
        previous_page: (page - 1 if page > 1),
        next_page: (page + 1 if page < PROFILE_PAGES.size),
        current_page: page
      ) { PROFILE_PAGES.fetch(page - 1, []) },
    }
  end

  def deferred
    render inertia: 'TestComponent', props: {
      user_stats: InertiaRails.defer(group: 'sidebar_group') { { visit_count: 1 } },
      remembered_props: InertiaRails.once { { remembered_at: 1 } },
      keyed_props: InertiaRails.once(key: 'a_key_of_its_own') { {} },
      revenue_report: InertiaRails.defer(rescue: true) { raise 'the report could not be built' },
    }
  end

  def flashed
    flash.now.inertia[:payment_completed] = 'done'

    render inertia: 'TestComponent', props: { user_profiles: [] }
  end

  def meta_tagged
    inertia_meta.add(name: 'description', content: 'the profiles you are browsing')

    render inertia: 'TestComponent', props: { user_profiles: [] }
  end
end
