class Chat < ActiveRecord::Base
  require 'rubygems'
  require 'aws-sdk'
  require 'push_notification'
  attr_accessor :platform

  belongs_to :event
  validates :chat_type, :sender_id,:member_ids,presence: { :message => "This field is required." }
  after_create :set_date_time, :set_event_timezone
  after_create :send_puch_notification, :create_analytic_record, :update_last_updated_model

  def update_last_updated_model
    LastUpdatedModel.update_record(self.class.name)
  end

  def get_sender_name(id)
    Invitee.find_by_id(id).name_of_the_invitee rescue ""
  end

  def get_member_name(ids)
    names = ""
    names = Invitee.where("id IN(?)",ids.split(",")).map {|i| i.name_of_the_invitee} rescue ""
    names.join(",")
  end

  def set_date_time
    self.update_column(:date_time, Time.now)
  end

  def set_event_timezone
    event = self.event
    self.update_column("event_timezone", event.timezone)
    self.update_column("event_timezone_offset", event.timezone_offset)
    self.update_column("event_display_time_zone", event.display_time_zone)
  end

  def send_puch_notification
    receivers = Invitee.where(:id => self.member_ids.split(',').map{|a| a.to_i}) rescue nil
    event = self.event
    mobile_application = event.mobile_application rescue nil
    push_pem_file = mobile_application.push_pem_file rescue nil
    ios_obj = Grocer.pusher("certificate" => push_pem_file.pem_file.url.split('?').first, "passphrase" => push_pem_file.pass_phrase, "gateway" => push_pem_file.push_url) rescue nil
    if self.sender_id.present? and receivers.present? and push_pem_file.present?
      self.send_to_receivers(receivers, mobile_application, push_pem_file, ios_obj)
    end
  end

  def send_to_receivers(receivers, mobile_application, push_pem_file, ios_obj)
    sender = Invitee.find_by_id(self.sender_id)
    event = Event.find(self.event_id)
    if sender.present?
      receivers.each do |receiver|
        b_count = receiver.get_badge_count
        ios_devices = receiver.devices.where(:platform => 'ios', :mobile_application_id => mobile_application.id).where.not(:enabled => "false")
        android_devices = receiver.devices.where(:platform => 'android', :mobile_application_id => mobile_application.id).where.not(:enabled => "false")
        title = (event.marketing_app ? mobile_application.name : event.event_name)
        if ios_devices.present?
          ios_devices.each do |device|
            Rails.logger.info("***********#{device.platform}*******************#{device.token}***************#{device.email}*************************************")
            Chat.push_to_ios(device.token, self.message, push_pem_file, ios_obj, b_count, 'chat', 0, sender, self.member_ids,self.event_id, title)
          end
        end
        if android_devices.present?
          Rails.logger.info("***********#{android_devices.pluck(:platform)}*******************#{android_devices.pluck(:token)}***************#{android_devices.pluck(:email)}*************************************")
          Chat.push_to_android(android_devices.pluck(:token), self.message, push_pem_file, b_count, 'chat', 0, sender, self.member_ids,self.event_id, title)
        end
      end
    end
  end

  def self.push_to_ios(token, msg, push_pem_file, ios_obj, b_count, push_page, page_id, sender, member_ids, event_id, title)
    notification = Grocer::Notification.new("device_token" => token, "alert"=>{"title"=> title, "body"=> "#{sender.get_invitee_name}: #{msg}", "action"=> "Read"}, "badge" => b_count, "sound" => "siren.aiff", "custom" => {"push_page" => push_page, "id" => page_id, 'sender_id' => sender.id, 'sender_name' => sender.get_invitee_name, "message_text"=> msg, 'member_ids' => member_ids, 'event_id' => event_id, 'time' => Time.now.strftime('%d/%m/%Y %H:%M')})
    response = ios_obj.push(notification)
  end

  def self.push_to_android(tokens, msg, push_pem_file, b_count=1, push_page='', page_id='', sender, member_ids, event_id, title)
    gcm_obj = GCM.new(push_pem_file.android_push_key)
    options = {'data' => {'message' => msg, 'page' => push_page, 'page_id' => 0, 'title' => title, 'sender_id' => sender.id, 'sender_name' => sender.get_invitee_name, 'member_ids' => member_ids, 'event_id' => event_id, 'time' => Time.now.strftime('%d/%m/%Y %H:%M')}}
    response = gcm_obj.send(tokens, options)
    Rails.logger.info("******************************#{response}***************response of gcm*************************************")
  end

  def create_analytic_record
    if Analytic.where('viewable_type = ? and action = ? and invitee_id = ? and event_id = ? and Date(created_at) = ?', "Chat", self.chat_type, self.sender_id, self.event_id, Date.today).blank?
      analytic = Analytic.new(viewable_type: "Chat", viewable_id: self.id, action: self.chat_type, invitee_id: self.sender_id, event_id: self.event_id, platform: self.platform)
      analytic.save rescue nil
    end
  end

  def created_at_with_event_timezone
    # self.created_at.in_time_zone(self.event_timezone)
    self.created_at + self.event_timezone_offset.to_i.seconds
  end

  def updated_at_with_event_timezone
    # self.updated_at.in_time_zone(self.event_timezone)
    self.updated_at + self.event_timezone_offset.to_i.seconds
  end

end