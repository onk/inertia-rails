# frozen_string_literal: true

RSpec.describe 'camelize_props on the parameters', type: :request do
  let(:headers) { { 'X-Inertia' => 'true' } }

  describe 'the body' do
    it 'is read under the names the controller declared' do
      post '/camelize_params',
           params: { userProfile: { firstName: 'Jane', phoneNumbers: [{ numberType: 'mobile' }] } },
           headers: headers

      expect(response.parsed_body).to eq('first_name' => 'Jane', 'phone_numbers' => [{ 'number_type' => 'mobile' }])
    end

    it 'keeps clear of the key ParamsWrapper wraps a JSON body under' do
      post '/camelize_params', params: { userProfile: { firstName: 'Jane' } }, headers: headers, as: :json

      expect(response.parsed_body).to eq('first_name' => 'Jane')
    end

    it 'is wrapped like any other JSON body when it carries no wrapper key' do
      post '/camelize_params', params: { firstName: 'Jane' }, headers: headers, as: :json

      expect(response.parsed_body).to eq('first_name' => 'Jane')
    end

    it 'drops a name the client was not given, however deep it sits' do
      allow(Rails.logger).to receive(:warn)

      post '/camelize_params/echo',
           params: { sort_order: 'newest', userProfile: { first_name: 'Jane' } },
           headers: headers

      expect(response.parsed_body).to include('keys' => %w[user_profile controller action], 'user_profile_keys' => [])
      expect(Rails.logger).to have_received(:warn).with(/sort_order/)
      expect(Rails.logger).to have_received(:warn).with(/first_name/)
    end

    # What a dropped name costs is the action's to say, as for a parameter the client never sent.
    it 'leaves a declaration that named a dropped parameter to answer for it' do
      expect { post '/camelize_params', params: { user_profile: { first_name: 'Jane' } }, headers: headers }
        .to raise_error(ActionController::ParameterMissing)
    end

    it 'keeps names starting with an underscore, which convert to themselves' do
      post '/camelize_params/echo', params: { _method: 'post', userProfile: { _destroy: '1' } }, headers: headers

      expect(response.parsed_body)
        .to include('keys' => include('_method', 'user_profile'), 'user_profile_keys' => %w[_destroy])
    end

    it 'is left alone for a request that is not an Inertia one' do
      post '/camelize_params/echo', params: { userProfile: { firstName: 'Jane' } }

      expect(response.parsed_body['keys']).to include('userProfile')
    end

    it 'is left alone for a controller that did not ask for camelize_props' do
      post '/plain_params/echo', params: { userProfile: { firstName: 'Jane' } }, headers: headers

      expect(response.parsed_body['keys']).to include('userProfile')
    end
  end

  describe 'the query string' do
    it 'is left alone, whichever case its names are in' do
      get '/camelize_params/echo', params: { sort_order: 'newest', filterBy: 'all' }, headers: headers

      expect(response.parsed_body['keys']).to include('sort_order', 'filterBy')
    end
  end

  describe 'the path parameters' do
    it 'keep the names the route declared' do
      get '/camelize_params/echo/1', headers: headers

      expect(response.parsed_body['keys']).to include('profile_id')
    end
  end
end
