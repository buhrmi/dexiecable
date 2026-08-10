require "application_system_test_case"

class MessageSyncTest < ApplicationSystemTestCase
  setup do
    Message.delete_all
    visit root_path
    assert_selector "h1", text: "Messages"
    # Clear Dexie DB from previous test runs
    page.execute_script("window.dexieDB.tables.forEach(t => t.clear())")
  end

  test "streams_to_dexie pushes created record to frontend via ActionCable" do
    Message.create!(body: "Hello from DexieCable!")

    assert_selector "#messages p[data-id]", text: "Hello from DexieCable!", wait: 10
  end

  test "with: Symbol uses the named method to serialize the record" do
    Message.create!(body: "Symbol serialized")

    assert_selector "#custom-messages p[data-id]", text: "Symbol serialized [symbol]", wait: 10
  end

  test "with: Proc uses the proc to serialize the record" do
    Message.create!(body: "Proc serialized")

    assert_selector "#proc-messages p[data-id]", text: "Proc serialized [proc]", wait: 10
  end
end
