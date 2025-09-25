module Pioneer
  class SalesforceSyncService < BaseSalesforceSyncService
    protected

    def get_salesforce_service
      Pioneer::SalesforceService.new
    end

    def get_app_type
      "pioneer"
    end
  end
end
