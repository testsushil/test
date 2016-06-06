class Admin::LeaderboardsController < ApplicationController
	layout 'admin'
  before_filter :authenticate_user, :authorize_event_role
	
	def index
		@invitees = Invitee.unscoped.where(:event_id => @event.id, :visible_status => 'active').order('points desc').first(5)
		respond_to do |format|
      format.html  
      format.xls do
        only_columns = [:name_of_the_invitee, :email, :designation, :company_name, :points]
        method_allowed = [:rank]
        send_data @invitees.to_xls(:only => only_columns, :methods => method_allowed)
      end
    end
	end
end
