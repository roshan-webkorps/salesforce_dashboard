module Legacy
  class SalesforceSyncService < BaseSalesforceSyncService
    protected

    def get_salesforce_service
      Legacy::SalesforceService.new
    end

    def get_app_type
      "legacy"
    end
  end
end
