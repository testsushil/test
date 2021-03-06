class Qna < ActiveRecord::Base
  include AASM
  attr_accessor :platform, :sender_email
  belongs_to :event
  has_many :favorites, as: :favoritable, :dependent => :destroy

  validates :question, :receiver_id,:sender_id, presence: { :message => "This field is required." }
  after_create :set_status_as_per_auto_approve, :create_analytic_record#, :set_event_timezone
  after_save :update_last_updated_model, :clear_cache

  default_scope { order('created_at desc') }

  aasm :column => :status do  # defaults to aasm_state
    state :pending, :initial => true
    state :approved
    state :rejected

    event :approve do
      transitions :from => [:pending,:rejected], :to => [:approved]
    end 
    event :reject do
      transitions :from => [:pending,:approved], :to => [:rejected]
    end
  end

  def update_last_updated_model
    LastUpdatedModel.update_record(self.class.name)
  end

  def clear_cache
    Rails.cache.delete("qna_get_speaker_name_#{self.id}")
    Rails.cache.delete("qna_get_panel_name_#{self.id}")
    Rails.cache.delete("qna_get_user_name_#{self.id}")
    Rails.cache.delete("qna_get_company_name_#{self.id}")
  end

  def change_status(event)
    if event== "approve"
      self.approve!
    elsif event== "reject"
      self.reject!
    end
  end

  def self.search(params,ques_answers)
    keyword = params[:search][:keyword]
    ques_answers.where("question like (?) ", "%#{keyword}%")if keyword.present?
  end

  def get_speaker_name
    Rails.cache.fetch("qna_get_speaker_name_#{self.id}") { get_speaker_name! }
  end  

  def get_speaker_name!
    name = Panel.find_by_id(self.receiver_id).name rescue nil
    name = Speaker.find_by_id(self.receiver_id).speaker_name rescue '' if name.blank?
    name
  end

  def get_panel_name
    Rails.cache.fetch("qna_get_panel_name_#{self.id}") { get_panel_name! }
  end  

  def get_panel_name!
    Panel.find_by_id(self.receiver_id).present? ? Panel.find_by_id(self.receiver_id).name : "" 
  end 

  def get_user_name
    Rails.cache.fetch("qna_get_user_name_#{self.id}") { get_user_name! }
  end  

  def get_user_name!
    Invitee.find_by_id(self.sender_id).name_of_the_invitee rescue ""
  end

  def get_company_name
    Rails.cache.fetch("qna_get_company_name_#{self.id}") { get_company_name! }
  end  

  def get_company_name!
    Invitee.find_by_id(self.sender_id).company_name rescue ""
  end

  def Timestamp
    # self.created_at.in_time_zone(self.event_timezone).strftime("%d/%m/%Y %T")
    (self.created_at + self.event.timezone_offset.to_i.seconds).strftime("%d/%m/%Y %T")
  end
  
  def email_id
    Invitee.find_by_id(self.sender_id).email rescue nil
  end

  def name
    Invitee.find_by_id(self.sender_id).name_of_the_invitee rescue ""
  end
  
  def first_name
    Invitee.find_by_id(self.sender_id).first_name rescue ""
  end

  def last_name
    Invitee.find_by_id(self.sender_id).last_name rescue ""
  end

  def question_ask
    self.question
  end
  
  def speaker_name
    Panel.find_by_id(self.receiver_id).present? ? Panel.find_by_id(self.receiver_id).name : "" 
    # name = Panel.find_by_id(self.receiver_id).name rescue nil
    # name = Speaker.find_by_id(self.receiver_id).speaker_name if name.nil? rescue ""
    # name
  end

  def qna_status
    self.status
  end

  def self.get_unanswer(objs,qna_status)
    objs.where(:wall_answer => qna_status, :status => "approved")
  end

  def get_receiver_user_name
    Panel.find_by_id(self.receiver_id).name rescue ""
  end

  def set_status_as_per_auto_approve
    if Event.find(self.event_id).qna_auto_approve == "true"
      self.update_column(:status, "approved") 
    elsif Event.find(self.event_id).qna_auto_approve == "false"
      self.update_column(:status, "pending")
    end
  end

  def self.set_auto_approve(value,event)
    event.update_column(:qna_auto_approve, value)
  end

  def create_analytic_record
    analytic = Analytic.new(viewable_type: "Q&A", viewable_id: self.receiver_id, action: "question asked", invitee_id: self.sender_id, event_id: self.event_id, platform: platform)
    analytic.save rescue nil
  end

  def self.get_top_question_speakers(count, event_id, type, start_date, end_date)
    pids = Qna.where('event_id = ? and Date(created_at) >= ? and Date(created_at) <= ?', event_id, start_date, end_date).group(:receiver_id).count.sort_by{|k, v| v}.last(count)
  end

  # def set_event_timezone
  #   event = self.event
  #   self.update_column("event_timezone", event.timezone)
  #   self.update_column("event_timezone_offset", event.timezone_offset)
  #   self.update_column("event_display_time_zone", event.display_time_zone)
  # end
  
  def created_at_with_event_timezone
    # self.created_at.in_time_zone(self.event_timezone)
    self.created_at + self.event.timezone_offset.to_i.seconds
  end

  def updated_at_with_event_timezone
    # self.updated_at.in_time_zone(self.event_timezone)
    self.updated_at + self.event.timezone_offset.to_i.seconds
  end

end
