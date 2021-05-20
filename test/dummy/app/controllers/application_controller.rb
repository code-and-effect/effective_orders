class ApplicationController < ActionController::Base

  def authorize!(action, resource)
    true
  end

end
