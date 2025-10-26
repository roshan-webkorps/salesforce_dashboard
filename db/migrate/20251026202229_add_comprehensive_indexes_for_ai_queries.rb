class AddComprehensiveIndexesForAiQueries < ActiveRecord::Migration[8.0]
  def change
    # Foreign key indexes (if not already present)
    add_index :opportunities, :owner_salesforce_id unless index_exists?(:opportunities, :owner_salesforce_id)
    add_index :opportunities, :account_salesforce_id unless index_exists?(:opportunities, :account_salesforce_id)
    add_index :leads, :owner_salesforce_id unless index_exists?(:leads, :owner_salesforce_id)
    add_index :accounts, :owner_salesforce_id unless index_exists?(:accounts, :owner_salesforce_id)
    add_index :cases, :owner_salesforce_id unless index_exists?(:cases, :owner_salesforce_id)
    add_index :cases, :account_salesforce_id unless index_exists?(:cases, :account_salesforce_id)

    # Composite indexes for common AI query patterns on opportunities
    add_index :opportunities,
              [ :app_type, :is_test_opportunity, :is_closed, :is_won, :close_date ],
              name: 'idx_opps_ai_query_pattern',
              where: "is_test_opportunity = false"

    add_index :opportunities,
              [ :owner_salesforce_id, :app_type, :is_test_opportunity, :close_date ],
              name: 'idx_opps_owner_performance',
              where: "is_test_opportunity = false"

    add_index :opportunities,
              [ :app_type, :is_closed, :stage_name ],
              name: 'idx_opps_pipeline_queries',
              where: "is_closed = false AND is_test_opportunity = false"

    # Composite indexes for leads
    add_index :leads,
              [ :owner_salesforce_id, :app_type, :salesforce_created_date ],
              name: 'idx_leads_owner_queries'

    add_index :leads,
              [ :app_type, :status, :is_converted ],
              name: 'idx_leads_conversion_queries'

    # Composite indexes for accounts
    add_index :accounts,
              [ :owner_salesforce_id, :app_type ],
              name: 'idx_accounts_owner_queries'

    add_index :accounts,
              [ :app_type, :segment, :industry ],
              name: 'idx_accounts_segment_queries'

    # Composite indexes for cases
    add_index :cases,
              [ :owner_salesforce_id, :app_type, :status ],
              name: 'idx_cases_owner_queries'

    add_index :cases,
              [ :app_type, :priority, :status ],
              name: 'idx_cases_priority_queries'
  end
end
