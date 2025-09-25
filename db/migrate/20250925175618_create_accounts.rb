class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :salesforce_id, null: false
      t.string :name, null: false
      t.string :owner_salesforce_id
      t.datetime :salesforce_created_date
      t.decimal :arr, precision: 12, scale: 2
      t.string :status
      t.string :industry
      t.string :segment
      t.integer :employee_count
      t.string :app_type, default: 'legacy', null: false

      t.timestamps
    end

    add_index :accounts, :salesforce_id, unique: true
    add_index :accounts, :owner_salesforce_id
    add_index :accounts, :app_type
    add_index :accounts, :status
    add_index :accounts, :salesforce_created_date
  end
end
