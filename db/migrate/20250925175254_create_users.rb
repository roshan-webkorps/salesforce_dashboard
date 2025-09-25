class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :salesforce_id, null: false
      t.string :name, null: false
      t.string :email
      t.string :role
      t.boolean :is_active, default: true
      t.string :manager_salesforce_id
      t.string :app_type, default: 'legacy', null: false

      t.timestamps
    end

    add_index :users, :salesforce_id, unique: true
    add_index :users, :app_type
    add_index :users, :is_active
    add_index :users, :role
  end
end
