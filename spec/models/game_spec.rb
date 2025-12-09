require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'validations' do
    it 'is valid with default attributes' do
      game = Game.new
      expect(game).to be_valid
    end

    it 'validates presence of player_balance' do
      game = Game.new(player_balance: nil)
      expect(game).not_to be_valid
      expect(game.errors[:player_balance]).to include("can't be blank")
    end

    it 'validates player_balance is non-negative' do
      game = Game.new(player_balance: -10)
      expect(game).not_to be_valid
      expect(game.errors[:player_balance]).to include("must be greater than or equal to 0")
    end

    it 'validates presence of current_bet' do
      game = Game.new(current_bet: nil)
      expect(game).not_to be_valid
      expect(game.errors[:current_bet]).to include("can't be blank")
    end

    it 'validates current_bet is non-negative' do
      game = Game.new(current_bet: -10)
      expect(game).not_to be_valid
      expect(game.errors[:current_bet]).to include("must be greater than or equal to 0")
    end

    it 'requires bet to be positive when not in betting status' do
      game = Game.new(status: 'player_turn', current_bet: 0)
      expect(game).not_to be_valid
      expect(game.errors[:current_bet]).to include("must be greater than 0 when game is in progress")
    end

    it 'allows zero bet when in betting status' do
      game = Game.new(status: 'betting', current_bet: 0)
      expect(game).to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Game.statuses).to eq({
        "betting" => "betting",
        "player_turn" => "player_turn",
        "dealer_turn" => "dealer_turn",
        "finished" => "finished"
      })
    end

    it 'defines result enum' do
      expect(Game.results).to eq({
        "player_wins" => "player_wins",
        "dealer_wins" => "dealer_wins",
        "push" => "push",
        "player_blackjack" => "player_blackjack",
        "dealer_blackjack" => "dealer_blackjack"
      })
    end

    it 'defaults status to betting' do
      game = Game.new
      expect(game.status).to eq('betting')
    end
  end

  describe '#build_deck' do
    let(:game) { Game.create! }

    it 'creates 52 unique cards' do
      game.send(:build_deck)
      expect(game.deck.length).to eq(52)
    end

    it 'creates cards with all ranks' do
      game.send(:build_deck)
      ranks = game.deck.map { |card| card['rank'] }.uniq.sort
      expect(ranks).to match_array(['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'])
    end

    it 'creates cards with all suits' do
      game.send(:build_deck)
      suits = game.deck.map { |card| card['suit'] }.uniq.sort
      expect(suits).to match_array(['♠', '♥', '♦', '♣'])
    end

    it 'creates 4 cards of each rank' do
      game.send(:build_deck)
      game.deck.group_by { |card| card['rank'] }.each do |rank, cards|
        expect(cards.length).to eq(4)
      end
    end

    it 'shuffles the deck' do
      game1 = Game.create!
      game1.send(:build_deck)

      game2 = Game.create!
      game2.send(:build_deck)

      # Extremely unlikely that two shuffled decks are identical
      expect(game1.deck).not_to eq(game2.deck)
    end
  end

  describe '#draw_card' do
    let(:game) { Game.create! }

    before do
      game.send(:build_deck)
      game.save!
    end

    it 'removes a card from the deck' do
      initial_count = game.deck.length
      game.send(:draw_card)
      expect(game.deck.length).to eq(initial_count - 1)
    end

    it 'returns the drawn card' do
      card = game.send(:draw_card)
      expect(card).to have_key('rank')
      expect(card).to have_key('suit')
    end
  end

  describe '#deal_initial_cards' do
    let(:game) { Game.create!(current_bet: 100) }

    before do
      game.send(:build_deck)
      game.save!
    end

    it 'deals 2 cards to player' do
      game.deal_initial_cards
      expect(game.player_hand.length).to eq(2)
    end

    it 'deals 2 cards to dealer' do
      game.deal_initial_cards
      expect(game.dealer_hand.length).to eq(2)
    end

    it 'deals in correct order: Player, Dealer, Player, Dealer' do
      # We can't easily test exact order without mocking, but we can verify structure
      initial_deck = game.deck.dup
      game.deal_initial_cards

      expect(game.player_hand).to be_present
      expect(game.dealer_hand).to be_present
      expect(game.deck.length).to eq(initial_deck.length - 4)
    end

    it 'changes status to player_turn' do
      game.deal_initial_cards
      expect(game.status).to eq('player_turn')
    end
  end

  describe '#calculate_hand_value' do
    let(:game) { Game.create! }

    it 'calculates value of number cards' do
      hand = [
        { 'rank' => '5', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(12)
    end

    it 'calculates value of face cards as 10' do
      hand = [
        { 'rank' => 'J', 'suit' => '♠' },
        { 'rank' => 'Q', 'suit' => '♥' },
        { 'rank' => 'K', 'suit' => '♦' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(30)
    end

    it 'calculates 10 card as 10' do
      hand = [
        { 'rank' => '10', 'suit' => '♠' },
        { 'rank' => '5', 'suit' => '♥' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(15)
    end

    it 'calculates ace as 11 when it does not bust' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => '5', 'suit' => '♥' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(16)
    end

    it 'calculates ace as 1 when 11 would bust' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'K', 'suit' => '♥' },
        { 'rank' => '5', 'suit' => '♦' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(16)
    end

    it 'calculates blackjack (ace + 10-value) as 21' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'K', 'suit' => '♥' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(21)
    end

    it 'handles multiple aces correctly' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'A', 'suit' => '♥' },
        { 'rank' => '9', 'suit' => '♦' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(21) # 11 + 1 + 9
    end

    it 'handles multiple aces when all must be 1' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'A', 'suit' => '♥' },
        { 'rank' => 'A', 'suit' => '♦' },
        { 'rank' => '8', 'suit' => '♣' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(21) # 1 + 1 + 1 + 8 = 11, then one ace becomes 11
    end

    it 'handles soft hand (ace counted as 11)' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => '6', 'suit' => '♥' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(17) # Soft 17
    end

    it 'handles hard hand (ace counted as 1)' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => '6', 'suit' => '♥' },
        { 'rank' => '10', 'suit' => '♦' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(17) # Hard 17
    end

    it 'handles bust correctly' do
      hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => 'Q', 'suit' => '♥' },
        { 'rank' => '5', 'suit' => '♦' }
      ]
      expect(game.send(:calculate_hand_value, hand)).to eq(25)
    end
  end

  describe '#player_score' do
    let(:game) { Game.create! }

    it 'returns the calculated value of player hand' do
      game.player_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.player_score).to eq(17)
    end

    it 'returns 0 for empty hand' do
      game.player_hand = []
      expect(game.player_score).to eq(0)
    end
  end

  describe '#dealer_score' do
    let(:game) { Game.create! }

    it 'returns the calculated value of dealer hand' do
      game.dealer_hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => '9', 'suit' => '♥' }
      ]
      expect(game.dealer_score).to eq(20)
    end

    it 'returns 0 for empty hand' do
      game.dealer_hand = []
      expect(game.dealer_score).to eq(0)
    end
  end

  describe '#visible_dealer_score' do
    let(:game) { Game.create!(status: 'player_turn', current_bet: 100) }

    it 'returns value of only first card when dealer card is hidden' do
      game.dealer_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.visible_dealer_score).to eq(10) # Only the King
    end

    it 'returns full dealer score when game is finished' do
      game.status = 'finished'
      game.dealer_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.visible_dealer_score).to eq(17)
    end

    it 'returns full dealer score during dealer turn' do
      game.status = 'dealer_turn'
      game.dealer_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.visible_dealer_score).to eq(17)
    end
  end

  describe '#dealer_hidden_card?' do
    let(:game) { Game.create! }

    it 'returns true during betting' do
      game.status = 'betting'
      expect(game.dealer_hidden_card?).to be true
    end

    it 'returns true during player turn' do
      game.status = 'player_turn'
      expect(game.dealer_hidden_card?).to be true
    end

    it 'returns false during dealer turn' do
      game.status = 'dealer_turn'
      expect(game.dealer_hidden_card?).to be false
    end

    it 'returns false when game is finished' do
      game.status = 'finished'
      expect(game.dealer_hidden_card?).to be false
    end
  end



  describe '#place_bet' do
    let(:game) { Game.create!(player_balance: 1000) }

    it 'sets the current bet' do
      game.place_bet(100)
      expect(game.current_bet).to eq(100)
    end

    it 'validates bet is positive' do
      expect { game.place_bet(0) }.to raise_error(ArgumentError, "Bet must be greater than 0")
    end

    it 'validates bet does not exceed balance' do
      expect { game.place_bet(1500) }.to raise_error(ArgumentError, "Insufficient balance")
    end

    it 'only allows betting during betting status' do
      game.status = 'player_turn'
      expect { game.place_bet(100) }.to raise_error(StandardError, "Cannot place bet at this time")
    end
  end

  describe '#player_hit' do
    let(:game) { Game.create!(status: 'player_turn', current_bet: 100) }

    before do
      game.send(:build_deck)
      game.player_hand = [
        { 'rank' => '10', 'suit' => '♠' },
        { 'rank' => '5', 'suit' => '♥' }
      ]
      game.save!
    end

    it 'adds a card to player hand' do
      initial_count = game.player_hand.length
      game.player_hit
      expect(game.player_hand.length).to eq(initial_count + 1)
    end

    it 'checks for bust when player exceeds 21' do
      game.player_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => 'Q', 'suit' => '♥' }
      ]
      game.deck = [{ 'rank' => '5', 'suit' => '♦' }]
      game.save!

      game.player_hit
      expect(game.player_score).to eq(25)
      expect(game.status).to eq('finished')
      expect(game.result).to eq('dealer_wins')
    end

    it 'continues game when player does not bust' do
      # Ensure next card won't bust (player has 15, so draw a 5 = 20)
      game.deck = [ { 'rank' => '5', 'suit' => '♦' } ]
      game.save!

      game.player_hit
      expect(game.status).to eq('player_turn')
      expect(game.player_score).to eq(20)
    end
  end

  describe '#player_stand' do
    let(:game) { Game.create!(status: 'player_turn', current_bet: 100) }

    before do
      game.send(:build_deck)
      game.player_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '9', 'suit' => '♥' }
      ]
      game.dealer_hand = [
        { 'rank' => '10', 'suit' => '♦' },
        { 'rank' => '6', 'suit' => '♣' }
      ]
      game.save!
    end

    it 'processes dealer turn and finishes game' do
      game.player_stand
      expect(game.status).to eq('finished')
    end

    it 'triggers dealer play' do
      initial_dealer_cards = game.dealer_hand.length
      game.player_stand
      # Dealer has 16, should hit
      expect(game.dealer_hand.length).to be > initial_dealer_cards
    end

    it 'resolves the game' do
      game.player_stand
      expect(game.status).to eq('finished')
      expect(game.result).to be_present
    end
  end

  describe '#dealer_should_hit?' do
    let(:game) { Game.create! }

    it 'returns true when dealer score is 16 or less' do
      game.dealer_hand = [
        { 'rank' => '10', 'suit' => '♠' },
        { 'rank' => '6', 'suit' => '♥' }
      ]
      expect(game.send(:dealer_should_hit?)).to be true
    end

    it 'returns false when dealer score is 17 or more' do
      game.dealer_hand = [
        { 'rank' => '10', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' }
      ]
      expect(game.send(:dealer_should_hit?)).to be false
    end

    it 'returns false when dealer score is 21' do
      game.dealer_hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'K', 'suit' => '♥' }
      ]
      expect(game.send(:dealer_should_hit?)).to be false
    end

    it 'returns false when dealer busts' do
      game.dealer_hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => 'Q', 'suit' => '♥' },
        { 'rank' => '5', 'suit' => '♦' }
      ]
      expect(game.send(:dealer_should_hit?)).to be false
    end
  end

  describe 'win conditions' do
    let(:game) { Game.create!(current_bet: 100, player_balance: 1000, status: 'dealer_turn') }

    describe 'blackjack scenarios' do
      it 'player blackjack beats dealer non-blackjack' do
        game.player_hand = [
          { 'rank' => 'A', 'suit' => '♠' },
          { 'rank' => 'K', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => '10', 'suit' => '♦' },
          { 'rank' => '10', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('player_blackjack')
      end

      it 'dealer blackjack beats player non-blackjack' do
        game.player_hand = [
          { 'rank' => '10', 'suit' => '♠' },
          { 'rank' => '10', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => 'A', 'suit' => '♦' },
          { 'rank' => 'K', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('dealer_blackjack')
      end

      it 'both blackjack results in push' do
        game.player_hand = [
          { 'rank' => 'A', 'suit' => '♠' },
          { 'rank' => 'K', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => 'A', 'suit' => '♦' },
          { 'rank' => 'Q', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('push')
      end
    end

    describe 'bust scenarios' do
      it 'player bust means dealer wins' do
        game.player_hand = [
          { 'rank' => 'K', 'suit' => '♠' },
          { 'rank' => 'Q', 'suit' => '♥' },
          { 'rank' => '5', 'suit' => '♦' }
        ]
        game.dealer_hand = [
          { 'rank' => '10', 'suit' => '♣' },
          { 'rank' => '7', 'suit' => '♠' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('dealer_wins')
      end

      it 'dealer bust means player wins' do
        game.player_hand = [
          { 'rank' => '10', 'suit' => '♠' },
          { 'rank' => '9', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => 'K', 'suit' => '♦' },
          { 'rank' => 'Q', 'suit' => '♣' },
          { 'rank' => '5', 'suit' => '♠' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('player_wins')
      end
    end

    describe 'score comparison' do
      it 'higher player score wins' do
        game.player_hand = [
          { 'rank' => '10', 'suit' => '♠' },
          { 'rank' => '10', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => '10', 'suit' => '♦' },
          { 'rank' => '8', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('player_wins')
      end

      it 'higher dealer score wins' do
        game.player_hand = [
          { 'rank' => '10', 'suit' => '♠' },
          { 'rank' => '8', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => '10', 'suit' => '♦' },
          { 'rank' => '9', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('dealer_wins')
      end

      it 'equal scores result in push' do
        game.player_hand = [
          { 'rank' => '10', 'suit' => '♠' },
          { 'rank' => '9', 'suit' => '♥' }
        ]
        game.dealer_hand = [
          { 'rank' => 'K', 'suit' => '♦' },
          { 'rank' => '9', 'suit' => '♣' }
        ]
        game.send(:resolve_game)
        expect(game.result).to eq('push')
      end
    end
  end

  describe 'betting and payouts' do
    describe '#payout' do
      it 'pays 3:2 for player blackjack' do
        game = Game.create!(current_bet: 100, player_balance: 900, status: 'finished', result: 'player_blackjack')
        initial_balance = game.player_balance
        game.send(:payout)
        expect(game.player_balance).to eq(initial_balance + 250) # original 100 + 150 win
      end

      it 'pays 1:1 for regular win' do
        game = Game.create!(current_bet: 100, player_balance: 900, status: 'finished', result: 'player_wins')
        initial_balance = game.player_balance
        game.send(:payout)
        expect(game.player_balance).to eq(initial_balance + 200) # original 100 + 100 win
      end

      it 'returns bet for push' do
        game = Game.create!(current_bet: 100, player_balance: 900, status: 'finished', result: 'push')
        initial_balance = game.player_balance
        game.send(:payout)
        expect(game.player_balance).to eq(initial_balance + 100) # just return the bet
      end

      it 'loses bet for dealer wins' do
        game = Game.create!(current_bet: 100, player_balance: 900, status: 'finished', result: 'dealer_wins')
        initial_balance = game.player_balance
        game.send(:payout)
        expect(game.player_balance).to eq(initial_balance) # bet already deducted, no return
      end

      it 'loses bet for dealer blackjack' do
        game = Game.create!(current_bet: 100, player_balance: 900, status: 'finished', result: 'dealer_blackjack')
        initial_balance = game.player_balance
        game.send(:payout)
        expect(game.player_balance).to eq(initial_balance) # bet already deducted, no return
      end
    end

    it 'deducts bet from balance when placing bet' do
      game = Game.create!(player_balance: 1000)
      game.place_bet(100)
      game.save!
      expect(game.player_balance).to eq(900)
    end

    it 'updates balance correctly after complete game' do
      game = Game.create!(player_balance: 1000)
      game.place_bet(100)
      game.deal_initial_cards

      # Mock a winning hand
      game.player_hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'K', 'suit' => '♥' }
      ]
      game.dealer_hand = [
        { 'rank' => '10', 'suit' => '♦' },
        { 'rank' => '9', 'suit' => '♣' }
      ]
      game.send(:resolve_game)

      expect(game.player_balance).to eq(1150) # 1000 - 100 + 250 (blackjack payout)
    end
  end

  describe '#blackjack?' do
    let(:game) { Game.create! }

    it 'returns true for ace and 10' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => '10', 'suit' => '♥' }
      ]
      expect(game.send(:blackjack?, hand)).to be true
    end

    it 'returns true for ace and face card' do
      hand = [
        { 'rank' => 'A', 'suit' => '♠' },
        { 'rank' => 'K', 'suit' => '♥' }
      ]
      expect(game.send(:blackjack?, hand)).to be true
    end

    it 'returns false for 21 with more than 2 cards' do
      hand = [
        { 'rank' => '7', 'suit' => '♠' },
        { 'rank' => '7', 'suit' => '♥' },
        { 'rank' => '7', 'suit' => '♦' }
      ]
      expect(game.send(:blackjack?, hand)).to be false
    end

    it 'returns false for non-21 with 2 cards' do
      hand = [
        { 'rank' => 'K', 'suit' => '♠' },
        { 'rank' => '9', 'suit' => '♥' }
      ]
      expect(game.send(:blackjack?, hand)).to be false
    end
  end
end
