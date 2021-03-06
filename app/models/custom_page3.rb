class CustomPage3 < ActiveRecord::Base
  belongs_to :event
  validates_presence_of :page_type, presence:{ :message => "This field is required." }
  validate :check_url_or_description_is_present
  after_save :update_last_updated_model
  #after_save :update_site_url

  def check_url_or_description_is_present
    if self.page_type == "url" 
      errors.add(:site_url, "This field is required.") if self.site_url.blank?
      errors.add(:open_with, "This field is required.") if self.open_with.blank?
    end
    if self.page_type == "build_new"
      errors.add(:description, "This field is required.") if self.description.blank?
    end
  end

  def update_last_updated_model
    LastUpdatedModel.update_record(self.class.name)
  end

  def update_site_url
    if self.page_type == "build_new"
      self.update_column(:site_url, "#{APP_URL}/admin/events/#{self.event_id}/custom_page3s/#{self.id}")
    end
  end
end