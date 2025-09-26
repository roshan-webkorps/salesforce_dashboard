class AddRevenueFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :annual_revenue, :decimal, precision: 12, scale: 2
    add_column :accounts, :mrr, :decimal, precision: 12, scale: 2
    add_column :accounts, :amount_paid, :decimal, precision: 12, scale: 2

    # Add opportunity forecasting fields
    add_column :opportunities, :probability, :decimal, precision: 5, scale: 2
    add_column :opportunities, :expected_revenue, :decimal, precision: 12, scale: 2
    add_column :opportunities, :forecast_category, :string

    add_index :opportunities, :probability
    add_index :opportunities, :expected_revenue
  end
end
