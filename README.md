# Blackjack Rails Application

A Blackjack game built with Ruby on Rails following official Bicycle Cards rules.

### Payouts
- **Blackjack (Natural)**: 3:2 payout (bet + 1.5× bet)
- **Regular Win**: 1:1 payout (bet + bet)
- **Push (Tie)**: Bet returned
- **Loss**: Bet forfeited

### Additional Features
- Balance tracking across multiple rounds
- Card visibility rules (dealer's second card hidden until player stands)
- Real-time score display
- Input validation for bets

## Technology Stack

- **Ruby**: 3.3.6
- **Rails**: 8.0.2
- **Database**: PostgreSQL
- **CSS Framework**: Tailwind CSS
- **Testing**: RSpec

## Prerequisites

- Ruby 3.3.6 or higher
- PostgreSQL
- Bundler

## Installation

1. **Clone the repository**
   ```bash
   cd blackjack_app
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Set up the database**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```

4. **Start the server**
   ```bash
   bin/dev
   ```

   Or if you prefer to run without Tailwind watch:
   ```bash
   bin/rails server
   ```

5. **Visit the application**
   ```
   Open your browser to http://localhost:3333
   ```

## How to Play

1. **Start a New Game**
   - You begin with a balance of $1,000
   - Enter your bet amount (minimum $1, maximum your current balance)
   - Click "Deal Cards"

2. **Playing Your Hand**
   - You'll see your two cards and one of the dealer's cards
   - The dealer's second card is face-down (hidden)
   - Your current score is displayed

   **Options:**
   - **Hit**: Draw another card
   - **Stand**: Keep your current hand and let the dealer play

3. **Dealer's Turn**
   - After you stand, the dealer's hidden card is revealed
   - The dealer automatically draws cards until reaching 17 or higher
   - The dealer has no choice - must follow fixed rules

4. **Winning**
   - **Blackjack**: Ace + 10-value card in first 2 cards pays 3:2
   - **Bust**: Going over 21 means you lose
   - **Higher Score**: Closest to 21 without going over wins
   - **Push**: Same score as dealer returns your bet

5. **Continue Playing**
   - After each round, click "New Round" to play again
   - Your balance carries over between rounds

## Running Tests

The application includes comprehensive model tests covering all game logic.

**Run all tests:**
```bash
bundle exec rspec
```

**Run specific test file:**
```bash
bundle exec rspec spec/models/game_spec.rb
```

## Design Decisions

### Architecture
- **Single Model Approach**: All business logic contained in the `Game` model for simplicity
- **JSON Storage**: Card hands and deck stored as JSON for flexibility without additional tables
- **Stateful Games**: Each game persists to database allowing for potential game history features

### Game Logic
- **Bicycle Cards Rules**: Implementation follows official Bicycle Cards blackjack rules
- **Automatic Dealer**: Dealer has no choices - strictly follows hit on ≤16, stand on ≥17
- **Proper Card Dealing**: Correct order per official rules (dealer's second card is hidden)

## Game Rules Reference

Based on [Bicycle Cards Official Blackjack Rules](https://bicyclecards.com/how-to-play/blackjack)

### Card Values
- **Number cards (2-10)**: Face value
- **Face cards (J, Q, K)**: Worth 10
- **Aces**: Worth 1 or 11

### Dealer Rules (Mandatory)
- Must hit on 16 or under
- Must stand on 17 or more
- No strategic decisions allowed

### Win Conditions
1. **Blackjack** beats any non-blackjack hand
2. **Both blackjack** results in a push
3. **Bust** (>21) loses immediately
4. **Higher score** (≤21) wins
5. **Equal scores** result in a push
