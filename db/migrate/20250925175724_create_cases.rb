class CreateCases < ActiveRecord::Migration[8.0]
  def change
    create_table :cases do |t|
      t.string :salesforce_id, null: false
      t.string :account_salesforce_id
      t.string :owner_salesforce_id
      t.string :status
      t.string :priority
      t.string :case_type
      t.datetime :salesforce_created_date
      t.datetime :closed_date
      t.string :app_type, default: 'legacy', null: false

      t.timestamps
    end

    add_index :cases, :salesforce_id, unique: true
    add_index :cases, :account_salesforce_id
    add_index :cases, :owner_salesforce_id
    add_index :cases, :status
    add_index :cases, :app_type
    add_index :cases, :salesforce_created_date
  end
end
