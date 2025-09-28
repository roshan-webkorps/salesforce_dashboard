# app/services/ai/salesforce_summary_generator.rb
module Ai
  class SalesforceSummaryGenerator
    def initialize(bedrock_client)
      @bedrock_client = bedrock_client
    end

    def generate_business_summary(user_query, results, description, app_type)
      return nil if results.empty?

      begin
        app_display_name = app_type == "pioneer" ? "Pioneer" : "Legacy"

        data_insights = analyze_results_for_insights(results)

        summary_prompt = build_summary_prompt(
          user_query,
          description,
          results,
          data_insights,
          app_display_name
        )

        response = call_bedrock_api(summary_prompt, app_type)
        parsed = parse_response(response)
        parsed["summary"]
      rescue => e
        Rails.logger.error "Business summary generation error: #{e.message}"
        generate_fallback_summary(results, description)
      end
    end

    private

    def build_summary_prompt(user_query, description, results, data_insights, app_display_name)
      <<~PROMPT
        You are analyzing #{app_display_name} sales team performance data for: "#{user_query}"

        Query: #{description}
        Results: #{results.length} records found

        Key Data Insights: #{data_insights}

        Sample data (first 2 records):
        #{format_sample_data(results)}

        Create a POSITIVE, ENCOURAGING business-friendly summary that:
        1. **Explains what the data shows** in simple terms (avoid technical jargon)
        2. **Highlights 2-3 key successes** that matter to sales management
        3. **Frames any insights as growth opportunities** - never as problems or deficiencies
        4. **Keeps it concise** (maximum 3 sentences)
        5. **Uses plain English** - write as if explaining to a non-technical sales manager

        POSITIVE EXAMPLES:
        ✅ "Sarah leads with $450K in closed deals, showing excellent sales performance"
        ✅ "The team successfully closed 23 opportunities this month"
        ✅ "Great opportunity to leverage top performers for coaching and mentoring"
        ✅ "Pipeline shows healthy diversity across multiple industries"

        AVOID NEGATIVE FRAMING:
        ❌ "Low conversion rate" → ✅ "Opportunities for improved lead qualification"
        ❌ "Behind quota" → ✅ "Building momentum toward quarterly goals"
        ❌ "Poor performance" → ✅ "Focus areas for development and support"

        Respond with JSON only: {"summary": "your positive business summary"}
      PROMPT
    end

    def format_sample_data(results)
      results.first(2).map do |row|
        row.map { |k, v| "#{k}: #{format_sample_value(v)}" }.join(", ")
      end.join("\n")
    end

    def format_sample_value(value)
      case value
      when Numeric
        if value > 1000
          format_currency_or_number(value)
        else
          value
        end
      else
        value
      end
    end

    def format_currency_or_number(value)
      if value >= 1_000_000
        "#{(value / 1_000_000).round(1)}M"
      elsif value >= 1_000
        "#{(value / 1_000).round(1)}K"
      else
        value.round(2)
      end
    end

    def analyze_results_for_insights(results)
      return "No data" if results.empty?

      insights = []

      numeric_columns = results.first.select { |k, v| v.is_a?(Numeric) || (v.is_a?(String) && v.match?(/^\d+\.?\d*$/)) }

      numeric_columns.each do |column, _|
        values = results.map { |row| row[column].to_f }
        if values.length > 1
          avg = (values.sum / values.length).round(1)
          insights << "#{column.humanize}: average #{format_insight_value(avg)}, range #{format_insight_value(values.min)}-#{format_insight_value(values.max)}"
        else
          insights << "#{column.humanize}: #{format_insight_value(values.first)}"
        end
      end

      if results.first.key?("name") || results.first.key?("sales_rep_name") || results.first.key?("owner_name")
        total_records = results.length
        entity_type = determine_entity_type(results.first.keys)
        insights << "#{total_records} #{entity_type} analyzed"
      end

      insights.join("; ")
    end

    def format_insight_value(value)
      if value >= 1_000_000
        "$#{(value / 1_000_000).round(1)}M"
      elsif value >= 1_000
        "$#{(value / 1_000).round(1)}K"
      else
        value.round(2)
      end
    end

    def determine_entity_type(keys)
      if keys.any? { |k| k.include?("rep") || k.include?("owner") || k == "name" }
        "sales rep#{'s' if keys.length > 1}"
      elsif keys.any? { |k| k.include?("account") }
        "account#{'s' if keys.length > 1}"
      elsif keys.any? { |k| k.include?("opportunity") || k.include?("deal") }
        "opportunity#{'ies' if keys.length > 1}"
      elsif keys.any? { |k| k.include?("lead") }
        "lead#{'s' if keys.length > 1}"
      elsif keys.any? { |k| k.include?("case") }
        "case#{'s' if keys.length > 1}"
      else
        "result#{'s' if keys.length > 1}"
      end
    end

    def generate_fallback_summary(results, description)
      count = results.length
      entity = case description.downcase
      when /sales rep|rep|owner/ then count == 1 ? "sales rep" : "sales reps"
      when /account|customer/ then count == 1 ? "account" : "accounts"
      when /opportunity|deal/ then count == 1 ? "opportunity" : "opportunities"
      when /lead|prospect/ then count == 1 ? "lead" : "leads"
      when /case|ticket/ then count == 1 ? "case" : "cases"
      else "result#{'s' unless count == 1}"
      end

      "Found #{count} #{entity}. #{description}"
    end

    def call_bedrock_api(prompt, app_type)
      request_body = {
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 300,
        temperature: 0.1,
        system: "You generate concise, business-friendly summaries for sales team analytics data. Always respond with valid JSON only.",
        messages: [ { role: "user", content: prompt } ]
      }

      response = @bedrock_client.invoke_model({
        model_id: "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
        body: request_body.to_json,
        content_type: "application/json"
      })

      response_body = JSON.parse(response.body.read)
      response_body.dig("content", 0, "text")&.strip
    end

    def parse_response(response)
      return {} if response.nil? || response.strip.empty?

      # Clean response
      cleaned = response.strip
      cleaned = cleaned[1...-1] if cleaned.start_with?('"') && cleaned.end_with?('"')
      cleaned = cleaned.gsub('\\n', "\n").gsub('\\"', '"').gsub("\\\\", "\\")

      JSON.parse(cleaned)
    rescue JSON::ParserError => e
      Rails.logger.error "Summary JSON parsing failed: #{e.message}"

      summary_match = response.match(/"summary":\s*"((?:[^"\\]|\\.)*)"/m)
      if summary_match
        { "summary" => summary_match[1].gsub('\\"', '"').gsub("\\\\", "\\") }
      else
        { "summary" => "Analysis complete. Review the data above for insights." }
      end
    end
  end
end
