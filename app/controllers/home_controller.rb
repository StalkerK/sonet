#   Copyright (c) 2010-2012, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class HomeController < ApplicationController
  def show
    partial_dir = Rails.root.join("app", "views", "home")
    if user_signed_in?
      redirect_to stream_path
    elsif request.format == :mobile
      if partial_dir.join("_show.mobile.haml").exist? ||
         partial_dir.join("_show.mobile.erb").exist? ||
         partial_dir.join("_show.haml").exist?
        render :show
      else
        redirect_to user_session_path
      end
    elsif partial_dir.join("_show.html.haml").exist? ||
          partial_dir.join("_show.html.erb").exist? ||
          partial_dir.join("_show.haml").exist?
      render :show
    else
      render :default,
             layout: "application"
    end
  end

  def stat
    @popular_tags = ActsAsTaggableOn::Tagging.joins(:tag).limit(50).order('count(taggings.id) DESC').group(:tag).count

    case params[:range]
    when "week"
      range = 1.week
      @segment = t('admins.stats.week')
    when "2weeks"
      range = 2.weeks
      @segment = t('admins.stats.2weeks')
    when "month"
      range = 1.month
      @segment = t('admins.stats.month')
    else
      range = 1.day
      @segment = t('admins.stats.daily')
    end

    [Post, Comment, AspectMembership, User].each do |model|
      create_hash(model, :range => range)
    end

    @posts_per_day = Post.where("created_at >= ?", Date.today - 21.days).group("DATE(created_at)").order("DATE(created_at) ASC").count
    @most_posts_within = @posts_per_day.values.max.to_f

    @user_count = User.count

    #@posts[:new_public] = Post.where(:type => ['StatusMessage','ActivityStreams::Photo'],
    #                                 :public => true).order('created_at DESC').limit(15).all

  end

  def toggle_mobile
    if session[:mobile_view].nil?
      # we're most probably not on mobile, but user wants it anyway
      session[:mobile_view] = true
    else
      # switch from mobile to normal html
      session[:mobile_view] = !session[:mobile_view]
    end

    redirect_to :back
  end

  private

    def percent_change(today, yesterday)
    sprintf( "%0.02f", ((today-yesterday) / yesterday.to_f)*100).to_f
    end

    def create_hash(model, opts={})
    opts[:range] ||= 1.day
    plural = model.to_s.underscore.pluralize
    eval(<<DATA
      @#{plural} = {
        :day_before => #{model}.where(:created_at => ((Time.now.midnight - #{opts[:range]*2})..Time.now.midnight - #{opts[:range]})).count,
        :yesterday => #{model}.where(:created_at => ((Time.now.midnight - #{opts[:range]})..Time.now.midnight)).count,
        :two_weeks => #{model}.where(:created_at => ((Time.now.midnight - #{2.weeks})..Time.now.midnight)).count
      }
      @#{plural}[:change] = percent_change(@#{plural}[:yesterday], @#{plural}[:day_before])
DATA
    )
    end

end
