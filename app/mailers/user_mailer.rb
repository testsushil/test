class UserMailer < ActionMailer::Base
  # default from: 'contact@ascratech.com'

  # before_filter :set_credential
  # before_filter :set_from_email
 
  def welcome_email(sender, licensee)
    @smtp_setting = sender.get_licensee_admin.smtp_setting
    if @smtp_setting.present?
      set_credential(@smtp_setting)
      @licensee = licensee
      mail(to: 'shiv@ascratech.com', subject: 'Welcome to My Awesome Site', from: @smtp_setting.from_email)
    end  
  end

  def send_mail_to_new_invitee(invitee)
    @invitee = invitee
    mail(to: @invitee.email, subject: 'You have been invitted for event')
  end

  def send_event_mail_to_licensee(store_info)
    @mobile_application = MobileApplication.find(store_info.mobile_application_id)
    @licensee = @mobile_application.client.licensee
    mail(from: "info@hobnobspace.com", to: "info@hobnobspace.com", bcc: "minakshi@ascratech.com", subject: "Your #{@mobile_application.name} created")
  end

  def send_password_invitees(invitee)
    @smtp_setting = invitee.get_licensee_admin.smtp_setting
    if @smtp_setting.present?
      set_credential(@smtp_setting)
      @invitee = invitee
      @event = @invitee.event
      mobile_application = @event.mobile_application
      mail(to: invitee.email, subject: "Your #{mobile_application.name} App Credentials", from: @smtp_setting.from_email, :bcc => "shiv@ascratech.com")
    end  
  end

  private

  def set_credential(smtp_setting)
    hsh = {:user_name => smtp_setting.username, :password => smtp_setting.password, :domain => smtp_setting.domain, :address => smtp_setting.address, :port => 587, :authentication => :plain, :enable_starttls_auto => true}
    ActionMailer::Base.smtp_settings.merge!(hsh)
  end

end