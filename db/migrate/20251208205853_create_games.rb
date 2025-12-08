class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.json :deck, default: []
      t.json :player_hand, default: []
      t.json :dealer_hand, default: []
      t.integer :player_balance, default: 1000, null: false
      t.integer :current_bet, default: 0, null: false
      t.string :status, default: "betting", null: false
      t.string :result

      t.timestamps
    end
  end
end
