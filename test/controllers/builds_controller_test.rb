require "test_helper"

class BuildsControllerTest < ActionDispatch::IntegrationTest
  test "build version is available without signing in and cannot be cached" do
    get build_path, as: :json

    assert_response :success
    assert_equal Rails.application.config.x.build_version, response.parsed_body["version"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
