require 'httparty'
require 'json'
require 'nokogiri'
require 'date'

require_relative "liftapp-client/version"

module Liftapp

  class AccessDenied < StandardError; end

  class Client
    attr_reader :profile_hash
    attr_reader :name
    attr_reader :picture_url
    attr_reader :email

    def initialize(email, password)
      @user_agent = 'Lift/0.27.1779 CFNetwork/609.1.4 Darwin/13.0.0'

      @auth_options = { basic_auth: { username: email, password: password } }
      
      @options = {}
      @options.merge!(@auth_options)
      @options.merge!({ headers: {'User-Agent' => @user_agent }})

      response = HTTParty.get('https://www.lift.do/i/0/users/current', @options)

      raise AccessDenied, 'Invalid email/password' if response.response.code == '401'

      @email        = response['email']
      @profile_hash = response['profile_hash']
      @picture_url  = response['picture_url']
      @name         = response['name']
    end

    def dashboard
      HTTParty.get('https://www.lift.do/api/v4/dashboard', @options)
    end

    def stats
      HTTParty.get('https://www.lift.do/api/v3/enrollments/stats', @options)
    end

    def notifications
      HTTParty.get('https://www.lift.do/api/v3/notifications/', @options)
    end

    # Example opts limit: 30, offset: 0
    def plan_questions(plan_id, opts)
      HTTParty.get('https://www.lift.do/api/v3/plans/%d/questions' % plan_id, @options.merge(query: opts))
    end

    def plan_stats(plan_id)
      HTTParty.get('https://www.lift.do/api/v3/plans/%d/stats' % plan_id, @options)
    end

    def checkin(habit_id, instruction_id=nil, time=DateTime.now)
      data = {
        body: { habit_id: habit_id, instruction_id: instruction_id, date: time.to_s }
      }
      HTTParty.post('https://www.lift.do/api/v3/checkins', @options.merge(data))
    end

    def checkout(checkin_id)
      HTTParty.delete('https://www.lift.do/api/v3/checkins/%d' % checkin_id)
    end

    def checkin_data(habit_id)
      response = HTTParty.get('https://www.lift.do/users/%s/%d' % [@profile_hash, habit_id])

      doc = Nokogiri::HTML(response.body)

      month_names  = doc.search('.calendar h3')
      month_tables = doc.search('#profile-calendar table.cal-month')
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
        'habit-name' => doc.search('.profile-habit-name').first.content.strip,
        'checkins'     => checkins.sort
      }
    end
  end

end
