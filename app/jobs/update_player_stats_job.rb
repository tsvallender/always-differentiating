require "open-uri"

class UpdatePlayerStatsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # fpl all data api
    # When dealing with an API, I think it’s generally nice to wrap it in a single object.
    # For example, you’d have a single LeagueAPI object, and any communication you want to
    # do with the API happens through that. It keeps all the logic in a single place and
    # makes refactoring and changes much simpler. It also makes your jobs simpler. I’d advise
    # to aim for jobs that have almost no logic in—they just trigger logic that’s held elsewhere.
    # Partly this makes the logic easier to share, but mostly it makes it _much_ easier
    # to test.
    general_url = "https://fantasy.premierleague.com/api/bootstrap-static/"
    user_serialized = URI.open(general_url).read
    all_data = JSON.parse(user_serialized)
    # set the gameweek to generic
    gameweek = 0
    # set the deadline to generic
    deadline = ""
    # get the next gameweek and tweak the gameweek and deadline accordingly
    all_data["events"].each do |num|
      if num["is_next"] == true
        gameweek = num["id"]
        deadline = Time.zone.parse(num["deadline_time"]).utc
      end
    end
    # new version below, commenting while i work this out
    if Player.find_by(web_name: "Salah").past_ownership_stats.key?(gameweek) == false
    # if the last gameweek in the database is not the current gameweek
    # if SelectedByStat.last.gameweek != gameweek
      # for each player in the fpl api
      all_data["elements"].each do |player|
        # search for player record by fpl id
        # if record doesn't yet exist, create one
        if Player.find_by(fpl_id: player["id"]) == nil
          new_player = Player.new
          new_player.web_name = player["web_name"]
          puts "#{new_player.web_name} created"
          new_player.code = player["code"]
          new_player.element_type = player["element_type"]
          new_player.event_points = player["event_points"]
          new_player.first_name = player["first_name"]
          new_player.fpl_id = player["id"]
          new_player.photo = player["photo"]
          new_player.second_name = player["second_name"]
          new_player.team = player["team"]
          new_player.total_points = player["total_points"]
          new_player.shirt = player["team_code"]
          new_player.past_ownership_stats[gameweek.to_s] = player["selected_by_percent"].to_f
          new_player.save
          puts "#{new_player.web_name} added\n"
          # SelectedByStat.create!(
          #   gameweek: gameweek,
          #   selected_by: player["selected_by_percent"],
          #   player: new_player
          # )
          puts "stat created for #{new_player.web_name}\n"
        else
          player_record = Player.find_by(fpl_id: player["id"])
          player_record.total_points = player["total_points"]
          player_record.past_ownership_stats[gameweek.to_s] = player["selected_by_percent"].to_f
          player_record.save!
          # SelectedByStat.create!(
          #   gameweek: gameweek,
          #   selected_by: player["selected_by_percent"],
          #   player: player_record
          # )
          puts "stat created for #{player_record.web_name}\n"
        end
      end
    else
      print "Stats already logged for Gameweek #{gameweek}"
    end
    after_deadline = deadline + 90.minutes
    # get penalties one minute later
    GetPendingPenaltiesJob.perform_now
    # get current picks 90 minutes after deadline
    GetCurrentPicksJob.set(wait_until: after_deadline).perform_later
  end
end
