class CreatePromoCodeRedemptions < ActiveRecord::Migration[8.1]
  def change
    create_table :promo_code_redemptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :promo_code, null: false, foreign_key: true

      t.timestamps
    end
  end
end
