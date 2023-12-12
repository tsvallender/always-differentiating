require "open-uri"

class UpdatePlayerStatsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    general_url = "https://fantasy.premierleague.com/api/bootstrap-static/"
    user_serialized = URI.open(general_url).read
    all_data = JSON.parse(user_serialized)
    # get the current gameweek
    gameweek = 0
    all_data["events"].each do |num|
      if num["is_next"] == true
        gameweek = num["id"]
      end
    end
    if SelectedByStat.last.gameweek != gameweek
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
          new_player.save
          puts "#{new_player.web_name} added\n"
          SelectedByStat.create!(
            gameweek: gameweek,
            selected_by: player["selected_by_percent"],
            player: new_player
          )
          puts "stat created for #{new_player.web_name}\n"
        else
          player_record = Player.find_by(fpl_id: player["id"])
          player_record.total_points = player["total_points"]
          player_record.save!
          SelectedByStat.create!(
            gameweek: gameweek,
            selected_by: player["selected_by_percent"],
            player: player_record
          )
          puts "stat created for #{player_record.web_name}\n"
        end
      end
    else
      print "Stats already logged for Gameweek #{gameweek}"
    end
  end
end