class Game < ApplicationRecord
  # Enums
  enum :status, {
    betting: "betting",
    player_turn: "player_turn",
    dealer_turn: "dealer_turn",
    finished: "finished"
  }, default: "betting"

  enum :result, {
    player_wins: "player_wins",
    dealer_wins: "dealer_wins",
    push: "push",
    player_blackjack: "player_blackjack",
    dealer_blackjack: "dealer_blackjack"
  }, prefix: true

  # Validations
  validates :player_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :current_bet, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validate :bet_must_be_positive_when_playing

  # Public methods

  def place_bet(amount)
    raise StandardError, "Cannot place bet at this time" unless betting?
    raise ArgumentError, "Bet must be greater than 0" if amount <= 0
    raise ArgumentError, "Insufficient balance" if amount > player_balance

    self.current_bet = amount
    self.player_balance -= amount
    save!
  end

  def deal_initial_cards
    build_deck

    # Round 1: Player card (visible), Dealer card (visible)
    self.player_hand << draw_card
    self.dealer_hand << draw_card

    # Round 2: Player card (visible), Dealer card (hidden)
    self.player_hand << draw_card
    self.dealer_hand << draw_card

    self.status = "player_turn"
    save!
  end

  def player_hit
    self.player_hand << draw_card

    if player_score > 21
      self.status = "finished"
      self.result = "dealer_wins"
      payout
    end

    save!
  end

  def player_stand
    self.status = "dealer_turn"
    save!

    # Dealer plays
    while dealer_should_hit?
      self.dealer_hand << draw_card
    end

    resolve_game
    save!
  end

  def player_score
    calculate_hand_value(player_hand)
  end

  def dealer_score
    calculate_hand_value(dealer_hand)
  end

  def visible_dealer_score
    if dealer_hidden_card?
      calculate_hand_value([dealer_hand.first])
    else
      dealer_score
    end
  end

  def dealer_hidden_card?
    betting? || player_turn?
  end

  private

  def build_deck
    ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    suits = ["♠", "♥", "♦", "♣"]

    cards = []
    suits.each do |suit|
      ranks.each do |rank|
        cards << { "rank" => rank, "suit" => suit }
      end
    end

    self.deck = cards.shuffle
  end

  def draw_card
    self.deck.pop
  end

  def calculate_hand_value(hand)
    return 0 if hand.empty?

    total = 0
    aces = 0

    hand.each do |card|
      rank = card["rank"]

      if rank == "A"
        aces += 1
        total += 11
      elsif ["K", "Q", "J"].include?(rank)
        total += 10
      else
        total += rank.to_i
      end
    end

    # Adjust for aces
    while total > 21 && aces > 0
      total -= 10
      aces -= 1
    end

    total
  end

  def dealer_should_hit?
    score = dealer_score
    score < 17 && score <= 21
  end

  def resolve_game
    self.status = "finished"

    player_blackjack = blackjack?(player_hand)
    dealer_blackjack = blackjack?(dealer_hand)

    # Both blackjack = push
    if player_blackjack && dealer_blackjack
      self.result = "push"
    # Player blackjack beats dealer
    elsif player_blackjack
      self.result = "player_blackjack"
    # Dealer blackjack beats player
    elsif dealer_blackjack
      self.result = "dealer_blackjack"
    # Player busted
    elsif player_score > 21
      self.result = "dealer_wins"
    # Dealer busted
    elsif dealer_score > 21
      self.result = "player_wins"
    # Compare scores
    elsif player_score > dealer_score
      self.result = "player_wins"
    elsif dealer_score > player_score
      self.result = "dealer_wins"
    else
      self.result = "push"
    end

    payout
  end

  def payout
    case result
    when "player_blackjack"
      # Blackjack pays 3:2 (bet + 1.5x bet)
      self.player_balance += (current_bet * 2.5).to_i
    when "player_wins"
      # Regular win pays 1:1 (bet + bet)
      self.player_balance += current_bet * 2
    when "push"
      # Return the bet
      self.player_balance += current_bet
    when "dealer_wins", "dealer_blackjack"
      # Bet already deducted, no payout
    end
  end

  def blackjack?(hand)
    return false unless hand.length == 2
    calculate_hand_value(hand) == 21
  end

  def bet_must_be_positive_when_playing
    if !betting? && current_bet <= 0
      errors.add(:current_bet, "must be greater than 0 when game is in progress")
    end
  end
end
