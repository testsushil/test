class Api::V1::ConversationsController < ApplicationController
  skip_before_action :load_filter
  skip_before_action :authenticate_user!

  respond_to :json 
  def create
    event = Event.find_by_id(params[:event_id])
    if event.present?
      if params[:image].present?
        conversation = event.conversations.new(:description => params[:description], :image => params[:image].first, :user_id => params[:user_id] ) 
      else
        conversation = event.conversations.new(:description => params[:description], :user_id => params[:user_id] ) 
      end
      if conversation.save
        render :status=>406,:json=>{:status=>"Success",:message=>"Conversation Created Successfully." }
      else
        render :status=>406,:json=>{:status=>"Failure",:message=>"You need to pass these values: #{conversation.errors.full_messages.join(" , ")}" }
      end
    else
      render :status=>406,:json=>{:status=>"Failure",:message=>"Event Not Found."}
    end
  end

  def index
    event = Event.find_by_id(params[:event_id])
    if event.present?
      data = {}
      start_event_date = params[:previous_date_time].present? ? (params[:previous_date_time]) : "01/01/1990 13:26:58".to_time.utc
      end_event_date = Time.now.utc + 2.minutes
      conversations = event.conversations.where(:updated_at => start_event_date..end_event_date) rescue []
      data[:'conversations'] = conversations.as_json(:except => [:image_file_name, :image_content_type, :image_file_size, :image_updated_at], :methods => [:image_url,:company_name,:like_count,:user_name,:comment_count])
      conversation_ids = conversations.pluck(:id)
      info = Comment.where(:commentable_id => conversation_ids, commentable_type: "Conversation", :updated_at => start_event_date..end_event_date) rescue []
      data[:'comments'] = info.as_json(:only => [:id, :commentable_id, :commentable_type, :user_id, :description, :created_at, :updated_at], :methods => [:user_name]) rescue []
      render :status => 200, :json => {:status => "Success", :data => data}
    else
      render :status=>200, :json=>{:status=>"Failure",:message=>"Event Not Found."}
    end
  end

end