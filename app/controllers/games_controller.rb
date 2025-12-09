class GamesController < ApplicationController
  before_action :set_game, only: [ :show, :hit, :stand ]

  def new
    # Check if user wants to reset/start fresh
    if params[:reset]
      @balance = 1000
    else
      # Get the most recent FINISHED game to carry over balance
      @last_game = Game.where(status: "finished").order(created_at: :desc).first
      @balance = @last_game&.player_balance || 1000
      # Auto-reset to 1000 if player is broke
      @balance = 1000 if @balance <= 0
    end
  end

  def create
    @game = Game.new(game_params)

    begin
      @game.place_bet(params[:bet].to_i)
      @game.deal_initial_cards
      redirect_to game_path(@game)
    rescue ArgumentError, StandardError => e
      @balance = @game.player_balance
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @game = Game.find(params[:id])
  end

  def hit
    @game.player_hit
    redirect_to game_path(@game)
  end

  def stand
    @game.player_stand
    redirect_to game_path(@game)
  end

  def new_round
    @old_game = Game.find(params[:id])
    @new_game = Game.create!(player_balance: @old_game.player_balance)
    redirect_to new_game_path
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    # Check if resetting or continuing from last game
    if params[:reset]
      balance = 1000
    else
      last_game = Game.where(status: "finished").order(created_at: :desc).first
      balance = last_game&.player_balance || 1000
      # Auto-reset to 1000 if player is broke
      balance = 1000 if balance <= 0
    end

    { player_balance: balance }
  end
end
