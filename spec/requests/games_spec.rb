require 'rails_helper'

RSpec.describe "Games", type: :request do
  describe "GET /games/new" do
    it "returns http success" do
      get "/games/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /games" do
    it "creates a game and redirects to show" do
      post "/games", params: { bet: 100 }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /games/:id" do
    it "returns http success" do
      game = Game.create!(player_balance: 1000, current_bet: 100)
      game.deal_initial_cards
      get "/games/#{game.id}"
      expect(response).to have_http_status(:success)
    end
  end
end
