require 'test_helper'

class NotificationUpdateTest < ActiveSupport::TestCase
  test "valid notification update should be valid" do
    assert FactoryGirl.build(:notification_update).valid?
  end

  test "should be invalid without a first_name" do
    update = FactoryGirl.build(:notification_update)
    update.first_name = nil
    assert update.invalid?
  end

  test "should be invalid without a phone_number" do
    update = FactoryGirl.build(:notification_update)
    update.phone_number = nil
    assert update.invalid?
  end

  test "should be invalid without a delivery_method" do
    update = FactoryGirl.build(:notification_update)
    update.delivery_method = nil
    assert update.invalid?
  end

  test "should be invalid without a message_path" do
    update = FactoryGirl.build(:notification_update)
    update.message_path = nil
    assert update.invalid?
  end

  test "should be invalid without a delivery_date" do
    update = FactoryGirl.build(:notification_update)
    update.delivery_date = nil
    assert update.invalid?
  end

  test "should be valid without a delivery_expires date" do
    update = FactoryGirl.build(:notification_update)
    update.delivery_expires = nil
    assert update.valid?
  end

  test "should be valid without an uploaded_at datetime" do
    update = FactoryGirl.build(:notification_update)
    update.uploaded_at = nil
    assert update.valid?
  end

  test "should be valid without a response_code" do
    update = FactoryGirl.build(:notification_update)
    update.response_code = nil
    assert update.valid?
  end

  test "should be valid without an ext_user_id" do
    update = FactoryGirl.build(:notification_update)
    update.ext_user_id = nil
    assert update.valid?
  end

  test "should be sorted by id in ascending order" do
    n = FactoryGirl.create(:notification)
    [10,6,29,8,3].each do |id|
      update = FactoryGirl.create(:notification_update, :notification => n, :id => id)
    end
    assert_equal n.updates.map(&:id).sort, n.updates.map(&:id)
  end

  #----------------------------------------------------------------------------#
  # action:
  #--------
  test "should be invalid without an action" do
    assert FactoryGirl.build(:notification_update, :action => nil).invalid?
  end

  test "an unknown action should be invalid" do
    assert FactoryGirl.build(:notification_update,
      :action => 'WREAK_HAVOC'
    ).invalid?
  end

  test "an action of 'CREATE' should be valid" do
    assert FactoryGirl.build(:notification_update,
      :action => NotificationUpdate::CREATE
    ).valid?
  end

  test "an action of 'UPDATE' should be valid" do
    assert FactoryGirl.build(:notification_update,
      :action => NotificationUpdate::UPDATE
    ).valid?
  end

  test "an action of 'DESTROY' should be valid" do
    assert FactoryGirl.build(:notification_update,
      :action => NotificationUpdate::CANCEL
    ).valid?
  end

  #----------------------------------------------------------------------------#
  # notification:
  #--------------
  test "should be invalid without a notification" do
    assert FactoryGirl.build(:notification_update, :notification => nil).invalid?
  end

  test "can access notification from notification update" do
    assert FactoryGirl.build(:notification_update).notification
  end

  test "assigning a notification should set first name" do
    notification = FactoryGirl.create(:notification)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.first_name
  end

  test "assigning a notification should set phone_number" do
    notification = FactoryGirl.create(:notification)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.phone_number
  end

  test "assigning a notification should set delivery_method" do
    notification = FactoryGirl.create(:notification)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.delivery_method
  end

  test "assigning a notification should set message_path" do
    notification = FactoryGirl.create(:notification)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.message_path
  end

  test "assigning a notification should set delivery_date" do
    notification = FactoryGirl.create(:notification)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.delivery_date
  end

  test "assigning a notification w/ message w/ custom expire_days" do
    message = FactoryGirl.create(:message, :expire_days => 3)
    notification = FactoryGirl.create(:notification, :message => message)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_equal update.delivery_date + 3.days, update.delivery_expires
  end

  test "assigning a notification should set preferred_time" do
    enrollment = FactoryGirl.create(:enrollment, :preferred_time => '10-19')
    notification = FactoryGirl.create(:notification, :enrollment => enrollment)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_not_nil update.preferred_time
  end

  test "assigning a notification should set ext_user_id" do
    enrollment = FactoryGirl.create(:enrollment, :ext_user_id => 'x344493y:4')
    notification = FactoryGirl.create(:notification, :enrollment => enrollment)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_equal enrollment.ext_user_id, update.ext_user_id
  end

  test "assigning a cancelled notification should set action as CANCEL" do
    notification = FactoryGirl.create(:notification, :status => Notification::CANCELLED)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    update.notification = notification
    assert_equal NotificationUpdate::CANCEL, update.action
  end

  test "assigning notification w/ non-cancel action should not change action" do
    notification = FactoryGirl.create(:notification, :status => Notification::PERM_FAIL)
    update = FactoryGirl.build(:notification_update, :notification => nil)
    orig_action = update.action
    update.notification = notification
    assert_equal orig_action, update.action
  end

  #----------------------------------------------------------------------------#
  # scopes:
  #--------
  test "pending scope: returns updates that have not been uploaded to hub" do
    3.times do
      n = FactoryGirl.create(:notification)
      n.updates.each { |u| u.update_attributes(:uploaded_at => 2.days.ago) }
    end
    2.times { FactoryGirl.create(:notification) }
    assert_equal 2, NotificationUpdate.pending.count
  end

  #----------------------------------------------------------------------------#
  # variables:
  #-----------
  test "should be valid without variables" do
    update = FactoryGirl.build(:notification_update, :variables => nil)
    assert update.valid?
  end

  test "should return an empty hash by default" do
    update = FactoryGirl.build(:notification_update, :variables => nil)
    assert_equal({}, update.variables)
  end

end
