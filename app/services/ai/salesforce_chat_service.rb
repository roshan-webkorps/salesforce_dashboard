# app/services/ai/salesforce_chat_service.rb
module Ai
  class SalesforceChatService
    attr_reader :conversation_history, :data_context

    def initialize
      @conversation_history = []
      @data_context = {}
    end

    # Add data query exchange (matches GitHub/JIRA signature)
    def add_exchange(user_query:, sql_query:, sql_results:, ai_response:)
      exchange = {
        user_query: user_query,
        sql_query: sql_query,
        ai_response: ai_response,
        timestamp: Time.current,
        type: "data_query"
      }

      # Update context from results
      update_data_context(sql_results) if sql_results.any?

      @conversation_history << exchange
      @conversation_history = @conversation_history.last(5)  # Keep last 5 exchanges
    end

    # Add conversational exchange (no SQL)
    def add_conversational_exchange(user_query, ai_response)
      exchange = {
        user_query: user_query,
        ai_response: ai_response,
        timestamp: Time.current,
        type: "conversational"
      }

      @conversation_history << exchange
      @conversation_history = @conversation_history.last(5)
    end

    # Build context for AI prompts
    def build_context_for_prompt(app_type)
      return "" if @data_context.empty? && @conversation_history.empty?

      context_parts = [ "=== CONVERSATION CONTEXT ===" ]
      context_parts << "App Type: #{app_type}"
      context_parts << ""

      # Add recent conversation summary
      if @conversation_history.any?
        context_parts << "Recent conversation:"
        @conversation_history.last(3).each do |exchange|
          context_parts << "User: #{exchange[:user_query]}"
          context_parts << "Assistant: #{exchange[:ai_response][0..150]}..."
          context_parts << ""
        end
      end

      # Add data context
      if @data_context[:sales_reps]&.any?
        context_parts << "Sales reps in focus: #{@data_context[:sales_reps].join(', ')}"
      end

      if @data_context[:accounts]&.any?
        context_parts << "Accounts in focus: #{@data_context[:accounts].join(', ')}"
      end

      if @data_context[:opportunities]&.any?
        context_parts << "Opportunities in focus: #{@data_context[:opportunities].join(', ')}"
      end

      if @data_context[:leads]&.any?
        context_parts << "Recent leads: #{@data_context[:leads].join(', ')}"
      end

      if @data_context[:cases]&.any?
        context_parts << "Recent cases: #{@data_context[:cases].join(', ')}"
      end

      context_parts << ""
      context_parts << "When the user uses pronouns (he/she/they/their), they likely refer to the entities above."
      context_parts << "=== END CONTEXT ==="

      context_parts.join("\n")
    end

    # Clear all context
    def clear_context
      @conversation_history = []
      @data_context = {}
    end

    # Check if context exists
    def has_context?
      @conversation_history.any? || @data_context.any?
    end

    # Serialize to session
    def to_session_data
      {
        conversation_history: @conversation_history,
        data_context: @data_context
      }
    end

    # Restore from session
    def restore_from_session(session_data)
      return unless session_data.is_a?(Hash)

      @conversation_history = session_data[:conversation_history] || []
      @data_context = session_data[:data_context] || {}

      Rails.logger.info "Restored chat service: #{@conversation_history.length} exchanges, #{@data_context.keys.length} context keys"
    end

    private

    # Update data context from SQL results
    def update_data_context(sql_results)
      return unless sql_results.is_a?(Array) && sql_results.any?

      first_row = sql_results.first
      return unless first_row.is_a?(Hash)

      # Extract sales reps
      if first_row.key?("name") || first_row.key?("sales_rep") || first_row.key?("sales_rep_name")
        rep_names = sql_results.map { |row|
          row["name"] || row["sales_rep"] || row["sales_rep_name"]
        }.compact.uniq
        @data_context[:sales_reps] = rep_names.first(5) if rep_names.any?
      end

      # Extract accounts
      if first_row.key?("account_name") || first_row.key?("account")
        account_names = sql_results.map { |row|
          row["account_name"] || row["account"]
        }.compact.uniq
        @data_context[:accounts] = account_names.first(5) if account_names.any?
      end

      # Extract opportunities
      if first_row.key?("opportunity_name") || first_row.key?("opportunity")
        opp_names = sql_results.map { |row|
          row["opportunity_name"] || row["opportunity"]
        }.compact.uniq
        @data_context[:opportunities] = opp_names.first(5) if opp_names.any?
      end

      # Extract leads
      if first_row.key?("lead_name") || first_row.key?("company")
        lead_info = sql_results.map { |row|
          row["lead_name"] || row["company"]
        }.compact.uniq
        @data_context[:leads] = lead_info.first(5) if lead_info.any?
      end

      # Extract cases
      if first_row.key?("case_id") || first_row.key?("case_number")
        case_info = sql_results.map { |row|
          "Case #{row['case_id']}" || row["case_number"]
        }.compact.uniq
        @data_context[:cases] = case_info.first(5) if case_info.any?
      end
    end
  end
end
