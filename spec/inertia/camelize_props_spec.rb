# frozen_string_literal: true

RSpec.describe 'camelize_props', type: :request do
  let(:headers) { { 'X-Inertia' => 'true' } }
  let(:partial_headers) { headers.merge('X-Inertia-Partial-Component' => 'TestComponent') }

  describe 'the props' do
    it 'camelizes the prop names and the keys inside their values' do
      get '/camelize_props/plain', headers: headers

      expect(response.parsed_body['props']).to eq(
        'currentAccount' => { 'accountName' => 'Acme' },
        'userProfiles' => [{ 'profileId' => 1, 'createdAt' => '2026-09-21' }],
        'currentUser' => { 'firstName' => 'Jane', '_recordId' => 1 },
        'tagNames' => %w[first_tag second_tag],
        'posts' => []
      )
    end

    it 'camelizes the keys inside what a prop type returned' do
      get '/camelize_props/deferred', headers: partial_headers.merge('X-Inertia-Partial-Data' => 'userStats')

      expect(response.parsed_body['props']).to eq('userStats' => { 'visitCount' => 1 })
    end

    it 'is off unless asked for' do
      get prop_transformer_test_path, headers: headers

      expect(InertiaRails.configuration.camelize_props).to be(false)
    end

    it 'leaves the meta tags under the name the client reads them by' do
      get '/camelize_props/meta_tagged', headers: headers

      expect(response.parsed_body['props']).to have_key('_inertia_meta')
    end
  end

  describe 'the page metadata' do
    it 'names the merge props the way the props are named' do
      get '/camelize_props/merged', headers: headers

      expect(response.parsed_body).to include(
        'mergeProps' => %w[chatMessages blogPosts pagedPosts.postList],
        'prependProps' => %w[newArrivals],
        'deepMergeProps' => %w[userSettings],
        'matchPropsOn' => %w[blogPosts.postId pagedPosts.postList.postId]
      )
    end

    it 'names fields that exist in the items it matches on' do
      get '/camelize_props/merged', headers: headers
      prop, field = response.parsed_body['matchPropsOn'].first.split('.')

      expect(response.parsed_body['props'].fetch(prop).first).to have_key(field)
    end

    it 'camelizes the scroll prop names without touching their pagination' do
      get '/camelize_props/scrolling', headers: headers

      expect(response.parsed_body['scrollProps']).to eq(
        'userProfiles' => {
          'pageName' => 'page', 'previousPage' => nil, 'nextPage' => 2, 'currentPage' => 1, 'reset' => false,
        }
      )
    end

    it 'camelizes the deferred prop names but not the group they are under' do
      get '/camelize_props/deferred', headers: headers

      expect(response.parsed_body['deferredProps'])
        .to eq('sidebar_group' => %w[userStats], 'default' => %w[revenueReport])
    end

    it 'camelizes a once key taken from the prop name, and leaves one the controller chose alone' do
      get '/camelize_props/deferred', headers: headers

      expect(response.parsed_body['onceProps']).to eq(
        'rememberedProps' => { 'prop' => 'rememberedProps' },
        'a_key_of_its_own' => { 'prop' => 'keyedProps' }
      )
    end

    it 'camelizes the name of a prop that failed to resolve' do
      get '/camelize_props/deferred', headers: partial_headers.merge('X-Inertia-Partial-Data' => 'revenueReport')

      expect(response.parsed_body).to include('rescuedProps' => %w[revenueReport])
    end

    it 'camelizes the names it reports as shared' do
      get '/camelize_props/plain', headers: headers

      expect(response.parsed_body['sharedProps']).to eq(%w[currentAccount])
    end

    it 'camelizes the keys the client reads the flash by' do
      get '/camelize_props/flashed', headers: headers

      expect(response.parsed_body['flash']).to eq('paymentCompleted' => 'done')
    end
  end

  describe 'a partial reload' do
    def props_for(partial)
      get '/camelize_props/plain', headers: partial_headers.merge(partial)
      response.parsed_body['props'].keys
    end

    it 'returns the props asked for by the names the client was given' do
      expect(props_for('X-Inertia-Partial-Data' => 'userProfiles,posts')).to contain_exactly('userProfiles', 'posts')
    end

    it 'omits the props excepted by the names the client was given' do
      expect(props_for('X-Inertia-Partial-Except' => 'userProfiles'))
        .to contain_exactly('currentAccount', 'currentUser', 'tagNames', 'posts')
    end

    it 'reaches an element of a plain array by the name the client was given' do
      get '/camelize_props/plain', headers: partial_headers.merge('X-Inertia-Partial-Data' => 'tagNames.1')

      expect(response.parsed_body['props']).to eq('tagNames' => [nil, 'second_tag'])
    end

    it 'matches no prop by the name it was declared with' do
      expect(props_for('X-Inertia-Partial-Data' => 'user_profiles')).to be_empty
    end

    it 'excepts no prop by the name it was declared with' do
      expect(props_for('X-Inertia-Partial-Except' => 'user_profiles'))
        .to contain_exactly('currentAccount', 'userProfiles', 'currentUser', 'tagNames', 'posts')
    end

    it 'resets a merge prop by the name the client was given' do
      get '/camelize_props/scrolling', headers: partial_headers.merge('X-Inertia-Reset' => 'userProfiles')

      expect(response.parsed_body['scrollProps']['userProfiles']).to include('reset' => true)
    end

    it 'does not reset a merge prop by the name it was declared with' do
      get '/camelize_props/scrolling', headers: partial_headers.merge('X-Inertia-Reset' => 'user_profiles')

      expect(response.parsed_body['scrollProps']['userProfiles']).to include('reset' => false)
    end

    # A once key is either a camelized prop name or one the controller chose, which is left as it
    # is, so both come back as the client was given them.
    it 'skips once props the client already has, by either kind of once key' do
      get '/camelize_props/deferred',
          headers: headers.merge('X-Inertia-Except-Once-Props' => 'rememberedProps,a_key_of_its_own')

      expect(response.parsed_body['props']).not_to include('rememberedProps', 'keyedProps')
    end
  end

  # A scroll prop of more than one word whose metadata kept the declared name would send the
  # client looking for a prop that is not there, and it would replace the list it had
  # accumulated instead of appending to it.
  describe 'an infinite scroll' do
    def fetch_page(number, intent: nil)
      scroll_headers = partial_headers.merge('X-Inertia-Partial-Data' => 'userProfiles')
      scroll_headers['X-Inertia-Infinite-Scroll-Merge-Intent'] = intent if intent

      get '/camelize_props/scrolling', params: { page: number }, headers: scroll_headers
      response.parsed_body
    end

    # What the client does with a page: read the prop name out of the metadata, look the prop up
    # by it, and append. `fetch` raises on a name that names nothing.
    def merge(accumulated, page)
      name = page.fetch('scrollProps').keys.sole
      arriving = page.fetch('props').fetch(name)

      page.fetch('mergeProps', []).include?(name) ? accumulated + arriving : arriving
    end

    it 'accumulates the pages it is given' do
      accumulated = merge([], fetch_page(1))
      accumulated = merge(accumulated, fetch_page(2, intent: 'append'))

      expect(accumulated).to eq(
        [
          { 'profileId' => 1, 'createdAt' => '2026-09-20' },
          { 'profileId' => 2, 'createdAt' => '2026-09-21' }
        ]
      )
    end
  end
end
