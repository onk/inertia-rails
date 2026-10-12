# frozen_string_literal: true

class InertiaPlainParamsController < ApplicationController
  def echo
    render json: { keys: params.to_unsafe_h.keys }
  end
end
