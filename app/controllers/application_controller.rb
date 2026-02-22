class ApplicationController < ActionController::API
  before_action :authenticate_api_client!

  private

  def authenticate_api_client!
    token = extract_bearer_token
    @current_client = ApiClient.authenticate(token)

    unless @current_client
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    header.sub("Bearer ", "").strip
  end

  def current_client
    @current_client
  end
end
