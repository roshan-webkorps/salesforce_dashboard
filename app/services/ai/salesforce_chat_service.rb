# app/services/ai/salesforce_chat_service.rb
module Ai
  class SalesforceChatService
    attr_reader :conversation_history, :data_context

    def initialize
      @conversation_history = []
      @data_context = {}
    end

    def add_exchange(user_query, ai_response, query_results = nil)
      exchange = {
        user_query: user_query,
        ai_response: ai_response,
        timestamp: Time.current
      }

      if query_results && query_results[:success]
        update_data_context(query_results)
      end

      @conversation_history << exchange

      @conversation_history = @conversation_history.last(3)
    end

    def build_context_for_prompt(app_type)
      return "" if @data_context.empty?

      context_parts = [ "=== CURRENT DATA CONTEXT ===", "App Type: #{app_type}" ]

      if @data_context[:sales_reps]&.any?
        context_parts << "Recent Sales Reps: #{@data_context[:sales_reps].join(', ')}"
      end

      if @data_context[:accounts]&.any?
        context_parts << "Recent Accounts: #{@data_context[:accounts].join(', ')}"
      end

      if @data_context[:opportunities]&.any?
        context_parts << "Recent Opportunities: #{@data_context[:opportunities].join(', ')}"
      end

      if @data_context[:leads]&.any?
        context_parts << "Recent Leads: #{@data_context[:leads].join(', ')}"
      end

      if @data_context[:cases]&.any?
        context_parts << "Recent Cases: #{@data_context[:cases].join(', ')}"
      end

      context_parts << "When user says 'their', 'them', 'those', refer to the entities mentioned above."
      context_parts << "=== END CONTEXT ==="

      context_parts.join("\n")
    end

    def clear_context
      @conversation_history = []
      @data_context = {}
    end

    def has_context?
      @conversation_history.any? || @data_context.any?
    end

    def add_conversational_exchange(user_query, ai_response)
      exchange = {
        user_query: user_query,
        ai_response: ai_response,
        timestamp: Time.current,
        type: "conversational"
      }

      @conversation_history << exchange
      @conversation_history = @conversation_history.last(3)
    end

    private

    def update_data_context(query_results)
      return unless query_results[:raw_results]&.any?

      results = query_results[:raw_results]
      first_row = results.first

      if first_row.key?("name") || first_row.key?("sales_rep_name") || first_row.key?("owner_name")
        rep_names = results.map { |row| row["name"] || row["sales_rep_name"] || row["owner_name"] }.compact.uniq
        @data_context[:sales_reps] = rep_names.first(5) if rep_names.any? # Limit to 5
      end

      if first_row.key?("account_name") || first_row.key?("account_id")
        account_names = results.map { |row| row["account_name"] || row["account_id"] }.compact.uniq
        @data_context[:accounts] = account_names.first(5) if account_names.any?
      end

      if first_row.key?("opportunity_name") || first_row.key?("opp_name")
        opp_names = results.map { |row| row["opportunity_name"] || row["opp_name"] }.compact.uniq
        @data_context[:opportunities] = opp_names.first(5) if opp_names.any?
      end

      if first_row.key?("lead_name") || first_row.key?("company")
        lead_info = results.map { |row| row["lead_name"] || row["company"] }.compact.uniq
        @data_context[:leads] = lead_info.first(5) if lead_info.any?
      end

      if first_row.key?("case_id") || first_row.key?("case_number")
        case_info = results.map { |row| "Case #{row['case_id']}" || row["case_number"] }.compact.uniq
        @data_context[:cases] = case_info.first(5) if case_info.any?
      end
    end

    def clean_name(name)
      cleaned = name.to_s.gsub(/[-_](sf|salesforce|crm)$/i, "")
      cleaned.strip
    end
  end
end
