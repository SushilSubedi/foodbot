class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :telegram_id, null: false
      t.string :username
      t.string :first_name, null: false
      t.string :last_name
      t.string :language, default: 'en'
      t.string :timezone, default: 'Asia/Kathmandu'
      t.boolean :is_premium, default: false

      t.timestamps
    end

    add_index :users, :telegram_id, unique: true
  end
end
