class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.string :salesforce_id, null: false
      t.string :name, null: false
      t.string :company
      t.string :email
      t.string :status, null: false
      t.string :lead_source
      t.string :owner_salesforce_id
      t.datetime :salesforce_created_date
      t.boolean :is_converted, default: false
      t.datetime :conversion_date
      t.string :industry
      t.string :app_type, default: 'legacy', null: false

      t.timestamps
    end

    add_index :leads, :salesforce_id, unique: true
    add_index :leads, :owner_salesforce_id
    add_index :leads, :status
    add_index :leads, :is_converted
    add_index :leads, :app_type
    add_index :leads, :salesforce_created_date
  end
end
