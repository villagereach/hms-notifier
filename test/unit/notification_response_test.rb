require 'test_helper'

class NotificationResponseTest < ActiveSupport::TestCase
  test "valid notification response should be valid" do
    assert Factory.build(:notification_response).valid?
  end

  test "should be valid without an error_type" do
    assert Factory.build(:notification_response, :error_type => nil).valid?
  end

  test "should be valid without an error_msg" do
    assert Factory.build(:notification_response, :error_msg => nil).valid?
  end

  test "should be valid without a delivered_at date" do
    assert Factory.build(:notification_response, :delivered_at => nil).valid?
  end

  #----------------------------------------------------------------------------#
  # status:
  #--------
  test "should be invalid without a status" do
    assert Factory.build(:notification_response, :status => nil).invalid?
  end

  test "unexpected status values should be valid" do
    assert Factory.build(:notification_response, :status => 'EARTH_NOT_FOUND').valid?
  end

  #----------------------------------------------------------------------------#
  # save:
  #------
  test "should update notification's status on save" do
    response = Factory.create(:notification_response, :status => 'DELIVERED')
    assert_equal Notification::DELIVERED, response.notification.status
  end

  test "should update notification's delivered_at value on save" do
    response = Factory.create(:notification_response,
      :status => 'DELIVERED',
      :delivered_at => 1.day.ago
    )
    assert_equal response.delivered_at, response.notification.delivered_at
  end

  test "should not raise error when saving w/ invalid status" do
    response = Factory.create(:notification_response, :status => 'EARTH_NOT_FOUND')
    orig_status = response.notification.status
    assert_nothing_raised { response.save! }
  end

  #----------------------------------------------------------------------------#
  # relationship w/ Notification:
  #------------------------------
  test "should be invalid without a notification" do
    assert Factory.build(:notification_response, :notification => nil).invalid?
  end

  test "can access notification from notification response" do
    assert Factory.build(:notification_response).notification
  end

end
