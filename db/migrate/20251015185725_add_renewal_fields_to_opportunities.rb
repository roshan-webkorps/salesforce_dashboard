class AddRenewalFieldsToOpportunities < ActiveRecord::Migration[8.0]
  def change
    add_column :opportunities, :renewal_date, :date
    add_column :opportunities, :is_test_opportunity, :boolean, default: false
    add_column :opportunities, :record_type_name, :string

    add_index :opportunities, :renewal_date
    add_index :opportunities, :record_type_name
    add_index :opportunities, :is_test_opportunity
  end
end
