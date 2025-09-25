# lib/tasks/salesforce.rake
namespace :salesforce do
  namespace :legacy do
    desc "Initial sync of Legacy Salesforce data for the last year"
    task initial_sync: :environment do
      puts "Starting initial Legacy Salesforce data sync at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}..."

      # Check required environment variables
      required_vars = %w[
        LEGACY_SALESFORCE_USERNAME
        LEGACY_SALESFORCE_PASSWORD_TOKEN
        LEGACY_SALESFORCE_CLIENT_ID
        LEGACY_SALESFORCE_CLIENT_SECRET
      ]

      missing_vars = required_vars.select { |var| ENV[var].blank? }
      if missing_vars.any?
        puts "ERROR: Missing required environment variables: #{missing_vars.join(', ')}"
        exit 1
      end

      sync_service = Legacy::SalesforceSyncService.new
      result = sync_service.sync_all_data(1.year.ago)

      if result[:errors]&.any?
        puts "Legacy Salesforce sync completed with errors:"
        result[:errors].each { |error| puts "  - #{error[:error]}" }
      else
        puts "Legacy Salesforce sync completed successfully at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}!"
      end

      puts "Users: #{result[:users]}"
      puts "Accounts: #{result[:accounts]}"
      puts "Opportunities: #{result[:opportunities]}"
      puts "Leads: #{result[:leads]}"
      puts "Cases: #{result[:cases]}"
    end

    desc "Incremental sync of Legacy Salesforce data from the last day"
    task incremental_sync: :environment do
      puts "Starting incremental Legacy Salesforce data sync at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}..."

      # Check required environment variables
      required_vars = %w[
        LEGACY_SALESFORCE_USERNAME
        LEGACY_SALESFORCE_PASSWORD_TOKEN
        LEGACY_SALESFORCE_CLIENT_ID
        LEGACY_SALESFORCE_CLIENT_SECRET
      ]

      missing_vars = required_vars.select { |var| ENV[var].blank? }
      if missing_vars.any?
        puts "ERROR: Missing required environment variables: #{missing_vars.join(', ')}"
        exit 1
      end

      sync_service = Legacy::SalesforceSyncService.new
      result = sync_service.sync_all_data(1.day.ago)

      if result[:errors]&.any?
        puts "Legacy Salesforce sync completed with errors:"
        result[:errors].each { |error| puts "  - #{error[:error]}" }
      else
        puts "Legacy Salesforce sync completed successfully at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}!"
      end

      puts "Users: #{result[:users]}"
      puts "Accounts: #{result[:accounts]}"
      puts "Opportunities: #{result[:opportunities]}"
      puts "Leads: #{result[:leads]}"
      puts "Cases: #{result[:cases]}"
    end
  end

  namespace :pioneer do
    desc "Initial sync of Pioneer Salesforce data for the last year"
    task initial_sync: :environment do
      puts "Starting initial Pioneer Salesforce data sync at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}..."

      # Check required environment variables
      required_vars = %w[
        PIONEER_SALESFORCE_USERNAME
        PIONEER_SALESFORCE_PASSWORD_TOKEN
        PIONEER_SALESFORCE_CLIENT_ID
        PIONEER_SALESFORCE_CLIENT_SECRET
      ]

      missing_vars = required_vars.select { |var| ENV[var].blank? }
      if missing_vars.any?
        puts "ERROR: Missing required environment variables: #{missing_vars.join(', ')}"
        exit 1
      end

      sync_service = Pioneer::SalesforceSyncService.new
      result = sync_service.sync_all_data(1.year.ago)

      if result[:errors]&.any?
        puts "Pioneer Salesforce sync completed with errors:"
        result[:errors].each { |error| puts "  - #{error[:error]}" }
      else
        puts "Pioneer Salesforce sync completed successfully at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}!"
      end

      puts "Users: #{result[:users]}"
      puts "Accounts: #{result[:accounts]}"
      puts "Opportunities: #{result[:opportunities]}"
      puts "Leads: #{result[:leads]}"
      puts "Cases: #{result[:cases]}"
    end

    desc "Incremental sync of Pioneer Salesforce data from the last day"
    task incremental_sync: :environment do
      puts "Starting incremental Pioneer Salesforce data sync at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}..."

      # Check required environment variables
      required_vars = %w[
        PIONEER_SALESFORCE_USERNAME
        PIONEER_SALESFORCE_PASSWORD_TOKEN
        PIONEER_SALESFORCE_CLIENT_ID
        PIONEER_SALESFORCE_CLIENT_SECRET
      ]

      missing_vars = required_vars.select { |var| ENV[var].blank? }
      if missing_vars.any?
        puts "ERROR: Missing required environment variables: #{missing_vars.join(', ')}"
        exit 1
      end

      sync_service = Pioneer::SalesforceSyncService.new
      result = sync_service.sync_all_data(1.day.ago)

      if result[:errors]&.any?
        puts "Pioneer Salesforce sync completed with errors:"
        result[:errors].each { |error| puts "  - #{error[:error]}" }
      else
        puts "Pioneer Salesforce sync completed successfully at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}!"
      end

      puts "Users: #{result[:users]}"
      puts "Accounts: #{result[:accounts]}"
      puts "Opportunities: #{result[:opportunities]}"
      puts "Leads: #{result[:leads]}"
      puts "Cases: #{result[:cases]}"
    end
  end
end
