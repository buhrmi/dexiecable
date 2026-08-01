require "application_system_test_case"

class MessageSyncTest < ApplicationSystemTestCase
  test "syncs_to_dexie pushes created record to frontend via ActionCable" do
    visit root_path

    assert_selector "h1", text: "Messages"

    Message.create!(body: "Hello from DexieCable!")

    assert_selector "p[data-id]", text: "Hello from DexieCable!", wait: 10
  end
end
