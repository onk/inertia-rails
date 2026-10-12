# frozen_string_literal: true

class InertiaDevtoolsCamelizedController < ApplicationController
  inertia_config(camelize_props: true)

  inertia_share account_name: 'Acme'

  class ProfileCardSerializer
    def to_inertia = { display_name: InertiaRails.always { 'Jane' } }
    def inertia_prop_sources = { 'display_name' => [__FILE__, 9] }
  end

  def show
    render inertia: 'DevtoolsComponent', props: {
      user_profile: { first_name: InertiaRails.always { 'Jane' } },
      profile_card: ProfileCardSerializer.new,
    }
  end
end
