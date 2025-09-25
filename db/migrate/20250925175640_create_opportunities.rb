class CreateOpportunities < ActiveRecord::Migration[8.0]
  def change
    create_table :opportunities do |t|
      t.string :salesforce_id, null: false
      t.string :name, null: false
      t.string :account_salesforce_id, null: false
      t.string :owner_salesforce_id, null: false
      t.string :stage_name, null: false
      t.decimal :amount, precision: 12, scale: 2
      t.date :close_date
      t.datetime :salesforce_created_date
      t.boolean :is_closed, default: false
      t.boolean :is_won, default: false
      t.string :opportunity_type
      t.string :lead_source
      t.string :app_type, default: 'legacy', null: false

      t.timestamps
    end

    add_index :opportunities, :salesforce_id, unique: true
    add_index :opportunities, :account_salesforce_id
    add_index :opportunities, :owner_salesforce_id
    add_index :opportunities, :stage_name
    add_index :opportunities, [ :is_closed, :is_won ]
    add_index :opportunities, :app_type
    add_index :opportunities, :salesforce_created_date
  end
end
