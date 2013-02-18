require 'httparty'
require 'json'
require 'nokogiri'
require 'date'

require "liftapp-client/version"

module Liftapp

  class Client
    attr_accessor :profile_hash

    def initialize(email, password)
      @user_agent = 'Lift/0.27.1779 CFNetwork/609.1.4 Darwin/13.0.0'

      @auth_options = {basic_auth: {username: email, password: password}}
      
      @options = {}
      @options.merge!(@auth_options)
      @options.merge!({headers: {'User-Agent' => @user_agent}})

      response = HTTParty.get('https://www.lift.do/i/0/users/current', @options)
      @profile_hash = response['profile_hash']
    end

    def dashboard
      HTTParty.get('https://www.lift.do/api/v2/dashboard', @options)
    end

    def checkin(habit_id, time=DateTime.now)
      data = {body: {habit_id: habit_id, date: time.to_s}}
      HTTParty.post('https://www.lift.do/api/v1/checkins', @options.merge(data))
    end

    def checkout(checkin_id)
      HTTParty.delete('https://www.lift.do/api/v1/checkins/%d' % checkin_id)
    end

    def habit_activity(habit_id)
      HTTParty.get('https://www.lift.do/api/v2/habits/%d/activity' % habit_id, @options)
    end

    def checkin_data(habit_id)
      response = HTTParty.get('https://www.lift.do/users/%s/%d' % [@profile_hash, habit_id])

      doc = Nokogiri::HTML(response.body)

      month_names  = doc.search('//*[@id="profile-calendar"]/div/div/h3')
      month_tables = doc.search('#profile-calendar table')
      checkins = []

      while (!month_names.empty?)
        month_name  = month_names.shift
        month_table = month_tables.shift
        month_table.search('div.checked').each do |day|
          m_day = day.text
          checkins.push(Date.parse(m_day + ' ' + month_name.content))
        end
      end
      {
        'habit-name' => doc.search('.profile-habit-name').first.content,
        'checkins'     => checkins.sort
      }
    end
  end

end
