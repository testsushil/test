class RegistrationSetting < ActiveRecord::Base
  belongs_to :event 

  validates :login, :event_id, :registration, presence: true
  # validates :login_url, :login_surl, :reg_url, :reg_surl, presence: true, :if :registration == 'hobnob'
  # validates :forget_pass_url, :forget_pass_surl, presence: true
  validate :check_external_regi_and_login_present

  before_save :update_registation_login_url,:update_template_to_template_name
  after_save :update_registation_surl, :update_last_updated_model

  attr_accessor :template_name
  
  def update_last_updated_model
    LastUpdatedModel.update_record(self.class.name)
  end

  def update_registation_login_url
    if self.login == 'hobnob'
      event = self.event
      mobile_application = event.mobile_application
      self.login_url = "#{APP_URL}/admin/mobile_applications/#{mobile_application.id}/external_login?mobile_application_preview_code=#{mobile_application.preview_code}&mobile_application_code=#{mobile_application.submitted_code}"
      self.login_surl = "#{APP_URL}/admin/mobile_applications/#{mobile_application.id}/success"
    end
  end

  def update_registation_surl
    if self.registration == 'hobnob'
      event = self.event
      self.update_column(:reg_url ,"#{APP_URL}/admin/events/#{event.id}/user_registrations/new")
      self.update_column(:reg_surl ,"#{APP_URL}/admin/events/#{event.id}/success")
    end
  end
  def check_external_regi_and_login_present
    if self.registration == "external"
      errors.add(:external_reg_url, "This field is required.") if self.external_reg_url.blank?
      errors.add(:external_reg_surl, "This field is required.") if self.external_reg_surl.blank?
    end
    if self.login == "external"
      errors.add(:external_login_url, "This field is required.") if self.external_login_url.blank?
      errors.add(:external_login_surl, "This field is required.") if self.external_login_surl.blank?
    end
    if self.registration == "hobnob"
      errors.add(:template, "This field is required.") if self.template.blank?
    end
    if self.registration == "hobnob" and self.template.present? and self.template == "default"
      errors.add(:template_name, "This field is required.") if template_name.blank?
    end
  end

  def update_template_to_template_name
    if self.template.present? and self.template == "default" 
      self.template = template_name if template_name.present?
    end
  end

end
