class CreatePromoCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :promo_codes do |t|
      t.string :code
      t.integer :limit_increase
      t.integer :max_uses
      t.integer :uses_count
      t.boolean :active
      t.datetime :expires_at
      t.timestamps
    end
  end
end
