FactoryBot.define do
  factory :game do
    deck { "" }
    player_hand { "" }
    dealer_hand { "" }
    player_balance { 1 }
    current_bet { 1 }
    status { "MyString" }
    result { "MyString" }
  end
end
