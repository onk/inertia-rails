# frozen_string_literal: true

class InertiaCamelizeParamsController < ApplicationController
  inertia_config(camelize_props: true)

  # The key the parameters are renamed to, so that `ParamsWrapper` has something to collide with.
  wrap_parameters :user_profile, format: [:json]

  def create
    permitted = params.expect(user_profile: [:first_name, { phone_numbers: [[:number_type]] }])

    render json: permitted.to_h
  end

  def echo
    render json: {
      keys: params.to_unsafe_h.keys,
      user_profile_keys: params.fetch(:user_profile, {}).keys,
    }
  end
end
