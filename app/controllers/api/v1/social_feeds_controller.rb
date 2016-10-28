class Api::V1::SocialFeedsController < ApplicationController

	skip_before_filter :authenticate_user,:load_filter
	#caches_action :index, :expires_in => 5.minutes, cache_path: Proc.new {|controller_instance| "#{request.url.split('?').first}/#{controller_instance.params[:page]}"}
  
  require 'social_feed_api'

	def index
		@event = Event.find_by_id(params[:event_id]) 
		if @event.present? or @event.facebook_social_tags.present? or @event.twitter_social_tags.present? or @event.twitter_handle.present? or @event.instagram_social_tags.present?
			#@facebook_posts
			if @event.facebook_social_tags.present?
				@facebook_posts = get_feacebook_posts(@event.facebook_social_tags)
			else
				@facebook_posts = []
			end
		#twitter posts	
		if @event.twitter_social_tags.present? or @event.twitter_handle.present? 
			@twitter_posts = get_twitter_posts(@event)
		else
			@twitter_posts = []
		end
		#instagram
 		if @event.instagram_client_id and @event.instagram_code.present? and @event.instagram_secret_token.present?  
      if @event.instagram_access_token.blank?
      	acess_token = `curl -F 'client_id=#{@event.instagram_client_id}' -F 'client_secret=#{@event.instagram_secret_token}' -F 'grant_type=authorization_code' -F 'redirect_uri=http://hobnobspace.com' -F 'code=#{@event.instagram_code}' -F 'response_type=token' -F 'scope=public_content' https://api.instagram.com/oauth/access_token`
      	acess_token = JSON.parse acess_token.gsub('=>', ':') 
      	insta_acess_token = acess_token["access_token"]
      	@event.update_column('instagram_access_token',insta_acess_token)
    	end
    	if request.format == "html"
    	 	session[:max_instagram_id] = nil
				user_details = HTTParty.get("https://api.instagram.com/v1/users/self/?access_token=#{@event.instagram_access_token}")
				user_id = user_details["data"]["id"] if user_details.present?
				session[:insta_user_id] = user_id if user_id.present? 
    	end
    	instagram_posts = SocialFeedApi.get_own_instgram_posts(@event,session[:max_instagram_id],session[:insta_user_id]) rescue []
    	if instagram_posts["data"].present? and instagram_posts["data"] != "data"
    		@instgram_embedded_post = get_instagram_posts(instagram_posts["data"])
    		session[:max_instagram_id] = instagram_posts["data"].last["id"]
    	else
				@instgram_embedded_post = []
    	end	
		else
			@instgram_embedded_post = []
		end
			@total_posts = @facebook_posts + @twitter_posts + @instgram_embedded_post
	  	@social_feeds =  @total_posts.sort_by { |hsh| hsh[:created_at] }.reverse!
		end
		# end		
  end


	def get_feacebook_posts(facebook_tags)
		#Rails.cache.fetch("facebook_posts_#{request.url}", :expires_in => 5.minutes) do
			session[:facebook_post_date] = (Date.today+1).to_date if request.format == "html"
			@posts = SocialFeedApi.get_facebook_posts(facebook_tags,session[:facebook_post_date])
			if 	@posts.present? && @posts["data"].present?
				session[:facebook_post_date] = @posts["data"].last["created_time"].to_date
			else
			  session[:facebook_post_date] = (session[:facebook_post_date]).to_date - 1		
			end
			data = []
			@posts["data"].each do |post|
				hsh = {:facebook_frames =>post["id"],:created_at=>post["created_time"].to_datetime}
				data << hsh
			end if @posts["data"].present?
			@facebook_posts = data
		#end	
	end	

	def get_twitter_posts(event)
		@twitter_tags =  @twitter_tags = event.twitter_social_tags.split(',').map{|x| '#'+x}.join(' OR ') if event.twitter_social_tags.present?
		@tweet_handle = event.twitter_handle if event.twitter_handle.present?
		session[:last_twitter_id] = nil if request.format == "html"
		session[:last_handle_id] = nil if request.format == "html"
		last_tweet_date = event.last_tweet_date.strftime("%Y-%m-%d") if event.last_tweet_date.present?
		@twitter_posts = CLIENT.search(@twitter_tags, result_type: "recent",since:"#{last_tweet_date}",max_id:session[:last_twitter_id],exclude:"retweets").take(4) rescue[] 
		@twitter_handle_post = CLIENT.search(@tweet_handle, result_type: "recent",since:"#{last_tweet_date}",max_id:session[:last_handle_id],exclude:"retweets").take(4) rescue[] 		
		session[:last_twitter_id] = @twitter_posts.last.id-1  if @twitter_posts.present?
		session[:last_handle_id] = @twitter_handle_post.last.id-1  if @twitter_handle_post.present?
		@twitter_posts = @twitter_posts + @twitter_handle_post 
		@twitter_posts = @twitter_posts.uniq.sort_by{ |k, v| k.created_at}.reverse!
	  data = []
	  @twitter_posts.each do |post|
		 	@posts = SocialFeedApi.get_twitter_posts(post.url)
			twitter_data = {:twitter_frame => @posts["html"],:created_at => post.created_at}
			data << twitter_data  
		end
		@posts = data
	end	

	def get_instagram_posts(instgram_post_data)
    instgram_embedded_post = []
    instgram_post_data.each do |post|
        url = post["link"]
        embedded_post = HTTParty.get("https://api.instagram.com/oembed/?url=#{url}&amp;maxwidth=320&amp;omitscript=true")
        hash = { :insta_frame=>embedded_post["html"],:created_at=>Time.at(post["created_time"].to_i)}
        instgram_embedded_post << hash if embedded_post.present?
    end
	  @instgram_embedded_post = instgram_embedded_post     
	end

end