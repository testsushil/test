class Admin::EventsController < ApplicationController
  layout 'admin'

  load_and_authorize_resource :except => [:create]
  before_filter :authenticate_user
  before_filter :authorize_client_role, :find_client_association
  before_filter :check_moderator_role, :feature_redirect_on_condition, :only => [:index]
  before_filter :get_event_names, :only => [:new, :create, :edit, :update]

  def index
    if params["type"].present?
      @events = Event.sort_by_type(params["type"], @events)
    end
    if (params[:search].present? && params[:search][:order_by].present? && params[:search][:order_by] == "All") || (params[:search].present? && params[:search][:order_by_status].present? && params[:search][:order_by_status] == "All")
      @events
    else 
      @events = Event.search(params, @events) if params[:search].present?
    end
    @select = true if (params[:feature].present? and params[:redirect_page].present? and params[:redirect_page] == "copy_event")
    @events = @events.ordered.paginate(page: params[:page], per_page: 10) if (@select != true)
    mobile_application_ids = @events.pluck(:mobile_application_id)
    single_mobile_application_ids = @client.mobile_applications.where('id IN (?) and application_type = ?', mobile_application_ids, 'single event').pluck(:id)
    if single_mobile_application_ids.present?
      @multi_mobile_applications = @client.mobile_applications.where('id NOT IN (?)', single_mobile_application_ids)
    else
      @multi_mobile_applications = @client.mobile_applications
    end
  end

  def new
    @event = @client.events.build
    @event.images.build unless (params[:marketing_app].present? and params[:marketing_app] == "true")
  #@event.event_venues.build    
  @themes = Theme.find_themes()
    @default_features = @event.set_features_default_list
    @present_feature = @event.set_features rescue []
    if (params[:marketing_app].present? and params[:marketing_app] == "true")
      result = @event.create_marketing_app_event
      if result == "true"
        redirect_to new_admin_event_mobile_application_path(:event_id=>@event.id,:old_one => true)
      else
        redirect_to :back
      end
    end
  end
  
  def create
    @event = @client.events.new(events_params)
    @event.set_time(params["event"]["start_event_date"], params["event"]["start_time_hour"], params["event"]["start_time_minute"], params["event"]["start_time_am"], params["event"]["end_event_date"], params["event"]["end_time_hour"], params["event"]["end_time_minute"], params["event"]["end_time_am"]) rescue nil
    @event.set_status_for_licensee if current_user.has_role? :licensee_admin
    @themes = Theme.find_themes()
    if @event.save 
      if params[:event][:copy_event].present? and params[:event][:copy_event] == 'yes'
        event = Event.find(params[:event][:parent_event_id])
        @event.update_columns(parent_id: event.id,default_feature_icon: event.default_feature_icon,about: event.about)
        if params[:event][:copy_content].present?
          @event.copy_event_associations_from(event)
        elsif params[:event][:custom_content].present?
          @event.copy_custom_event_associations_from(event, params)
        end
      end

      @event.add_default_invitee if @event.mobile_application.present?
      redirect_to admin_client_event_path(:client_id => @event.client_id, :id => @event.id)
    else
      #@landing_page = @event.landing_page if @event.landing_page.present?
      @default_features = @event.set_features_default_list
      @present_feature = @event.set_features rescue []
      render :action => 'new'
    end
  end
    
  def show
    redirect_to admin_client_event_path(:client_id => @client.id, :id => @event.id, :analytics => "true") if params[:detailed_analytics].nil? and params[:analytics].nil? and @event.mobile_application.present? #and (!current_user.has_role_for_event?("db_manager", @event.id,session[:current_user_role]))
    mobile_application_ids = @events.pluck(:mobile_application_id).compact
    single_mobile_application_ids = @client.mobile_applications.where('id IN (?) and application_type = ?', mobile_application_ids, 'single event').pluck(:id)
    @multi_mobile_applications = single_mobile_application_ids.present? ? @client.mobile_applications.where('id NOT IN (?)', single_mobile_application_ids) : @client.mobile_applications
    if params[:detailed_analytics].present? and @event.mobile_application.present?
      params[:filter_date], params[:start_date] = 'date range', params[:start_date].present? ? params[:start_date].to_date : Date.today - 2.weeks
      params[:end_date] = params[:end_date].present? ? params[:end_date].to_date : Date.today
      @detailed_analytics_counts = Analytic.get_detailed_analytics(params)
    elsif params[:analytics].present? and @event.mobile_application.present? and (params[:end_date].present? and params[:start_date].present?) and (params[:end_date].to_date - params[:start_date].to_date).to_i > 31
      @date_filter_error = true
    elsif params[:analytics].present?  
      @live_analytics = Analytic.get_live_analytics(params)
    end
  end

  def edit
    @present_users = @event.users.pluck(:id)
    @users = User.all
    @themes = Theme.find_themes()
    @default_features = @event.set_features_default_list
    @present_feature = @event.set_features
    #@event.event_venues.build
  end

  def update
    if params[:status].present?
      update_status_and_redirect and return
    elsif params[:schedule_type].present?
      schedule_date = params[:schedule_type] == "ongoing" ? Date.today : Date.today + 1
      @event.update(:start_event_date => schedule_date) rescue nil
      redirect_to admin_client_events_path(:client_id => @client.id, :page => params[:page]) rescue nil
    else
      if params["event"]["start_event_date"].present?
        @event.set_time(params["event"]["start_event_date"], params["event"]["start_time_hour"], params["event"]["start_time_minute"], params["event"]["start_time_am"], params["event"]["end_event_date"], params["event"]["end_time_hour"], params["event"]["end_time_minute"], params["event"]["end_time_am"]) rescue nil
      end
      if @event.update_attributes(events_params)
        if params[:event][:copy_event].present? and params[:event][:copy_event] == 'yes'
          event = Event.find(params[:event][:parent_event_id])
          @event.update_columns(parent_id: event.id,default_feature_icon: event.default_feature_icon)   
          if params[:event][:copy_content].present?
            @event.copy_event_associations_from(event)
          elsif params[:event][:custom_content].present?
            @event.copy_custom_event_associations_from(event, params)
          end
          redirect_to admin_event_mobile_application_path(:id => @event.mobile_application.id, :event_id => @event.id, :type => "show_engagement")
        elsif params[:set_activity_feed_bool].present?
          redirect_to admin_event_mobile_application_path(:id => @event.mobile_application.id, :event_id => @event.id, :type => "show_engagement")
        else
          redirect_to admin_client_events_path(:client_id => @client.id)
        end
      else
        @default_features = @event.set_features_default_list
        @present_feature = @event.set_features
        @themes = Theme.find_themes()
        render :action => "edit"
      end
    end
  end

  def destroy
    if @event.destroy
      redirect_to admin_client_events_path(:client_id => @event.client_id)
    end
  end

  protected

  def get_event_names
    @event_names = @client.events.where(marketing_app: nil).where.not(status: 'rejected').pluck(:event_name, :id)
    source_event = Event.find(params[:event_id])
    @active_modules = source_event.get_active_module
  end

  def feature_redirect_on_condition
    if params[:feature].present? and params[:feature]  != "events"
      event_count = (current_user.has_role? "moderator" or current_user.has_role? :event_admin or current_user.has_role? "telecaller" or current_user.has_role? :db_manager) ? @events.count("events.id") : @events.count
      if params[:event_id].present? or (@events.present? and event_count == 1 and params[:feature] != "mobile_application" and params[:feature] != "mobile_applications")
        @event = (event_count == 1) ? @events.first : @events.find(params[:event_id])
        if params[:feature] == "mobile_application"
          if @event.present? and params[:type] == 'remove'
            @event.update_column(:mobile_application_id, nil)
            redirect_to :back
          elsif @event.present? and params[:redirect_page] == "show"
            redirect_to admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id)
          elsif @event.present? and params[:redirect_page] == "edit"
            redirect_to edit_admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id)
          else
            @event.update_column(:mobile_application_id, params[:mobile_application_id])
            @event.add_default_invitee
            redirect_to admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id)
          end
        elsif params[:feature] == "mobile_applications" and params[:client_id].present?
          if @event.mobile_application.present?
            redirect_to edit_admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id)
          else
            redirect_to new_admin_event_mobile_application_path(:event_id => @event.id)
          end
        elsif params[:feature] == "mobile_applications"
          if @event.mobile_application.present?
            redirect_to admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application.id)
          else
            redirect_to admin_client_mobile_applications_path(:client_id => @event.client_id)
          end  
        elsif params[:feature] == "analytics"
          if @event.mobile_application.present?
            redirect_to admin_client_event_path(:client_id => @event.client_id, :id => @event.id, :analytics => true)
          else
            redirect_to admin_client_event_path(:client_id => @event.client_id, :id => @event.id)
          end 
        elsif params[:feature] == "users"
          if @event.present? and params[:role].present? and params[:redirect_page] != "index"
            if params[:role] == "telecaller"
              redirect_to new_admin_event_telecaller_path(:event_id => @event.id,:from_client => "true")
            else
              redirect_to new_admin_event_user_path(:event_id => @event.id, :role => params[:role])
            end
          else
            redirect_to admin_event_users_path(:event_id => @event.id) if !(params[:wall].present?) and params[:dashboard].blank?
            redirect_to admin_event_users_path(:event_id => @event.id, :role => "all") if params[:dashboard].present?
            if current_user.has_role? :moderator
              redirect_to  admin_client_event_path(:client_id => @event.client_id,:id => @event.id) if params[:wall].present?
            else
              redirect_to admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id, :type =>"show_content") if params[:wall].present?
            end
          end  
        else
          single_associate = ["abouts", "event_highlights", "emergency_exits", 'role']
          single_associate_redirect = "/new" if single_associate.include?(params[:feature])
          redirect_to  "/admin/events/#{@event.id}/#{params[:feature]}#{single_associate_redirect}" 
        end
      else
        if params[:feature] == "mobile_application" and (params['type'] == 'remove' or params[:redirect_page] == "show" or params[:redirect_page] == "edit")
          @events = @events.where(:mobile_application_id => params[:mobile_application_id])
        elsif params[:feature] == "mobile_application" or params[:feature] == "mobile_applications"
          @events = @events.where(:status => 'approved', :mobile_application_id => nil)
        end
        @events = @events.where("status NOT IN(?)", ["pending","rejected"])
        @select = true
      end
    else
      if params["feature"] == "events" and @client.events.count == 0
        redirect_to new_admin_client_event_path(:client_id => @client.id)
      elsif current_user.has_role? :event_admin and (params["feature"] == "events" and Event.with_roles(current_user.roles.pluck(:name), current_user).length == 1)
        redirect_to admin_client_event_path(:client_id => @client.id, :id => Event.with_roles(current_user.roles.pluck(:name), current_user).last.id)
      end
    end
  end

  def check_moderator_role
    @events = Event.with_role(session[:current_user_role].to_sym, current_user).where(:client_id => params[:client_id]) if session[:current_user_role] == "moderator"
  end

  def events_params
    params.require(:event).permit!.except(:features)
  end

  def update_status_and_redirect
    @event.perform_event(params[:status])
    if @event.avg_review.to_i == 100 and @event.mobile_application.store_info.present?
      if params[:publish_unpublish] == "true"
        redirect_to admin_event_mobile_application_path(:event_id => @event.id,:id => @event.mobile_application.id)
      else  
        redirect_to admin_client_events_path(:client_id => @client.id, :page => params[:page])
      end
    elsif @event.mobile_application.present?
      redirect_to admin_event_mobile_application_path(:event_id => @event.id, :id => @event.mobile_application_id)
    else  
      redirect_to admin_client_events_path(:client_id => @client.id, :page => params[:page])
    end
  end

end
