# app/controllers/concerns/salesforce_bedrock_ai_query_processor.rb
module SalesforceBedrockAiQueryProcessor
  extend ActiveSupport::Concern

  MODEL_CONFIG = {
    model_id: "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
    max_tokens: 500,
    temperature: 0.1
  }.freeze

  def process_salesforce_bedrock_ai_query(user_query, app_type = "legacy", chat_service = nil)
    begin
      Rails.logger.info "=== SALESFORCE BEDROCK QUERY PROCESSING ==="
      Rails.logger.info "User Query: #{user_query}"
      Rails.logger.info "App Type: #{app_type}"
      Rails.logger.info "Has Context: #{chat_service&.has_context?}"

      unless is_data_query?(user_query)
        return handle_conversational_query(user_query, app_type, chat_service)
      end

      schema_context = get_salesforce_database_context(app_type)

      conversation_context = chat_service&.build_context_for_prompt(app_type) || ""

      ai_response = call_bedrock_api(user_query, app_type, schema_context, conversation_context)
      parsed_response = parse_ai_response(ai_response)

      if parsed_response["sql"].present?
        results = execute_safe_query(parsed_response["sql"])

        formatted_results = Ai::SalesforceChartFormatter.format_results(results, parsed_response, user_query)

        if formatted_results[:success] && results.any? && (results.length > 3 || parsed_response["chart_type"] != "table")
          bedrock_client = initialize_bedrock_client
          summary_generator = Ai::SalesforceSummaryGenerator.new(bedrock_client)
          summary = summary_generator.generate_business_summary(
            user_query, results, parsed_response["description"], app_type
          )
          formatted_results[:summary] = summary if summary
        end

        chat_service&.add_exchange(user_query, parsed_response, formatted_results)

        formatted_results[:processing_info] = {
          model_used: MODEL_CONFIG[:model_id],
          context_used: conversation_context.present?
        }

        formatted_results
      else
        { error: "Could not generate a valid query from your request." }
      end

    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parse Error: #{e.message}"
      { error: "Invalid response from AI service." }
    rescue => e
      Rails.logger.error "Salesforce Bedrock AI Query Error: #{e.message}"
      { error: "Sorry, I couldn't process your query. Please try rephrasing it." }
    end
  end

  def is_data_query?(user_query)
    data_keywords = [
      "show", "list", "find", "get", "top", "most", "least", "how many", "count", "features",
      "opportunities", "accounts", "leads", "cases", "users", "sales", "revenue", "pipeline",
      "deals", "wins", "closed", "open", "conversion", "performance", "stats", "metrics",
      "reps", "customers", "prospects", "support", "tickets", "activity", "month", "year"
    ]

    query_lower = user_query.downcase
    data_keywords.any? { |keyword| query_lower.include?(keyword) }
  end

  private

  def initialize_bedrock_client
    require "aws-sdk-bedrockruntime"

    Aws::BedrockRuntime::Client.new(
      region: ENV["AWS_REGION"] || "us-east-1",
      credentials: Aws::Credentials.new(
        ENV["AWS_ACCESS_KEY_ID"],
        ENV["AWS_SECRET_ACCESS_KEY"]
      )
    )
  end

  def call_bedrock_api(user_query, app_type, schema_context = "", conversation_context = "")
    client = initialize_bedrock_client
    system_prompt = build_system_prompt(app_type, schema_context, conversation_context)

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: MODEL_CONFIG[:max_tokens],
      temperature: MODEL_CONFIG[:temperature],
      system: system_prompt,
      messages: [ { role: "user", content: user_query } ]
    }

    response = client.invoke_model({
      model_id: MODEL_CONFIG[:model_id],
      body: request_body.to_json,
      content_type: "application/json"
    })

    response_body = JSON.parse(response.body.read)
    content = response_body.dig("content", 0, "text")
    content&.strip
  rescue => e
    Rails.logger.error "Bedrock API call error: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(3)}"
    raise
  end

  def build_system_prompt(app_type, schema_context, conversation_context, user_query = "")
    app_display_name = app_type == "pioneer" ? "Pioneer" : "Legacy"
    prompt_parts = []

    if conversation_context.present?
      prompt_parts << conversation_context
      prompt_parts << ""
    end

    prompt_parts << <<~BASE_PROMPT
      You are a SQL query generator for a Salesforce analytics dashboard.

      CRITICAL JSON FORMAT REQUIREMENTS:
      - ALWAYS respond with EXACTLY this JSON structure - no variations
      - Do NOT use WITH clauses, CTEs, or subqueries
      - Keep SQL simple with basic SELECT, JOIN, WHERE, GROUP BY, ORDER BY only
      - Use single quotes for all string values in SQL (not double quotes)
      - Do NOT use column aliases with double quotes like "Sales Rep Name"
      - Use simple column aliases: name AS sales_rep_name (no quotes)
      - For ORDER BY: use numbers (ORDER BY 1, 2) or repeat the expression, NOT column aliases

      REQUIRED RESPONSE FORMAT (copy this structure exactly):
      {"sql": "SELECT simple query here", "description": "Brief description", "chart_type": "bar"}

      DATABASE CONTEXT: You are querying #{app_display_name} Salesforce data only.
      #{schema_context}

      Database Tables:
      - users (id, salesforce_id, name, email, role, is_active, manager_salesforce_id, app_type)
      - accounts (id, salesforce_id, name, owner_salesforce_id, salesforce_created_date, arr, status, industry, segment, employee_count, annual_revenue, mrr, amount_paid, app_type)
      - opportunities (id, salesforce_id, name, account_salesforce_id, owner_salesforce_id, stage_name, amount, close_date, salesforce_created_date, is_closed, is_won, opportunity_type, lead_source, probability, expected_revenue, forecast_category, app_type)
      - leads (id, salesforce_id, name, company, email, status, lead_source, owner_salesforce_id, salesforce_created_date, is_converted, conversion_date, industry, app_type)
      - cases (id, salesforce_id, account_salesforce_id, owner_salesforce_id, status, priority, case_type, salesforce_created_date, closed_date, app_type)

      CRITICAL FILTERING RULE:
      - ALWAYS add "app_type = '#{app_type}'" to ALL table queries

      COMPARISON QUERY RULES:
      - For time comparisons like "January vs March" or "Q1 vs Q2", create AGGREGATE totals, not per-rep breakdowns
      - NEVER reference column aliases in ORDER BY - use column numbers instead
      - For "compare X vs Y" queries, return just TWO rows: one for each time period
      - Use UNION to combine separate time period queries into aggregate results
      - Format: SELECT 'Period Name' as period, COUNT/SUM as total

      DEFAULT TIME FRAME RULE:
      - Unless a specific time frame is mentioned in the query, ALWAYS filter data to the last 1 month
      - For opportunities: use "salesforce_created_date >= NOW() - INTERVAL '1 month'" (or close_date if query is about closed deals)
      - For accounts: use "salesforce_created_date >= NOW() - INTERVAL '1 month'"
      - For leads: use "salesforce_created_date >= NOW() - INTERVAL '1 month'" (or conversion_date if query is about conversions)
      - For cases: use "salesforce_created_date >= NOW() - INTERVAL '1 month'" (or closed_date if query is about closed cases)
      - If user specifies a different time frame (e.g., "last 6 months", "this year", "last week"), use that instead
      - If query asks for "all time" or "ever" or similar, don't apply time filtering
      - For year comparisons, use current year 2025

      SQL SIMPLICITY RULES:
      1. ONLY use basic SELECT queries - no CTEs, no WITH clauses, no subqueries
      2. Always JOIN with users table to show names, not IDs (use owner_salesforce_id = users.salesforce_id)
      3. ALWAYS filter by app_type = '#{app_type}' for ALL tables
      4. Use simple column names in SELECT - no quoted aliases
      5. Use ORDER BY with numbers: ORDER BY 1 DESC, not ORDER BY alias_name DESC
      6. For UNION queries, ensure both SELECT statements have identical column structure
      7. Use appropriate LIMIT: LIMIT 5 for top/most queries, LIMIT 10 for lists, no LIMIT for counts or comparisons
      8. For opportunity stages, use proper mapping:
        - "closed/won/completed" = is_closed = true AND is_won = true
        - "open/pipeline" = is_closed = false
        - "lost/closed lost" = is_closed = true AND is_won = false
      9. For lead statuses, common values: 'New', 'Working', 'Qualified', 'Converted', 'Unqualified'
      10. For case priorities: 'High', 'Medium', 'Low', 'Critical'

      EXAMPLE RESPONSES:

      Simple query:
      {"sql": "SELECT u.name, COUNT(o.id) as opportunity_count FROM users u JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.salesforce_created_date >= NOW() - INTERVAL '1 month' GROUP BY u.name ORDER BY 2 DESC LIMIT 5", "description": "Top 5 sales reps with most opportunities created this month", "chart_type": "bar"}

      Comparison query (AGGREGATE format):
      {"sql": "SELECT 'January' as period, SUM(o.amount) as total FROM opportunities o JOIN users u ON o.owner_salesforce_id = u.salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.is_closed = true AND o.is_won = true AND o.close_date >= '2025-01-01' AND o.close_date < '2025-02-01' UNION SELECT 'March' as period, SUM(o.amount) as total FROM opportunities o JOIN users u ON o.owner_salesforce_id = u.salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.is_closed = true AND o.is_won = true AND o.close_date >= '2025-03-01' AND o.close_date < '2025-04-01'", "description": "Total revenue comparison between January and March 2025", "chart_type": "bar"}

      Chart types: "bar" for rankings/counts, "pie" for distributions, "table" for lists.

      Remember: Keep it simple, no complex SQL, exact JSON format only, use ORDER BY with numbers not aliases.
    BASE_PROMPT

    prompt_parts.join("\n")
  end

  def parse_ai_response(ai_response)
    return {} if ai_response.nil? || ai_response.strip.empty?

    cleaned_response = clean_response(ai_response)
    result = JSON.parse(cleaned_response)
    result
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing failed: #{e.message}"
    Rails.logger.info "Attempting regex extraction..."

    extracted = extract_with_regex(cleaned_response)
    Rails.logger.info "Regex extracted: #{extracted.inspect}"

    extracted || raise(JSON::ParserError, "Could not parse AI response")
  end

  def clean_response(response)
    cleaned = response.strip
    cleaned = cleaned[1...-1] if cleaned.start_with?('"') && cleaned.end_with?('"')
    cleaned.gsub('\\n', "\n").gsub('\\r', "\r").gsub('\\t', "\t").gsub('\\"', '"').gsub("\\\\", "\\")
  end

  def extract_with_regex(response)
    result = {}

    {
      "sql" => /"sql":\s*"((?:[^"\\]|\\.)*)"/m,
      "description" => /"description":\s*"((?:[^"\\]|\\.)*)"/m,
      "chart_type" => /"chart_type":\s*"((?:[^"\\]|\\.)*)"/m,
      "summary" => /"summary":\s*"((?:[^"\\]|\\.)*)"/m
    }.each do |key, pattern|
      match = response.match(pattern)
      result[key] = match[1].gsub('\\"', '"').gsub("\\\\", "\\") if match
    end

    result.any? ? result : nil
  end

  def get_salesforce_database_context(app_type)
    <<~SCHEMA
      === SALESFORCE DATABASE SCHEMA DETAILS ===

      users:
        - id (primary key)
        - salesforce_id (Salesforce User ID)
        - name (sales rep display name)
        - email, role, is_active
        - manager_salesforce_id, app_type

      accounts:
        - id, salesforce_id, name
        - owner_salesforce_id (foreign key to users.salesforce_id)
        - salesforce_created_date (timestamp)
        - arr, annual_revenue, mrr, amount_paid (revenue fields)
        - status, industry, segment, employee_count
        - app_type

      opportunities:
        - id, salesforce_id, name, stage_name
        - account_salesforce_id (foreign key to accounts.salesforce_id)
        - owner_salesforce_id (foreign key to users.salesforce_id)
        - amount, close_date, salesforce_created_date
        - is_closed, is_won (boolean flags)
        - opportunity_type, lead_source, probability, expected_revenue
        - app_type

      leads:
        - id, salesforce_id, name, company, email, status
        - lead_source, owner_salesforce_id
        - salesforce_created_date, is_converted, conversion_date
        - industry, app_type

      cases:
        - id, salesforce_id
        - account_salesforce_id (foreign key to accounts.salesforce_id)
        - owner_salesforce_id (foreign key to users.salesforce_id)
        - status, priority, case_type
        - salesforce_created_date, closed_date
        - app_type

      === RELATIONSHIPS ===
      - All tables have app_type column for filtering
      - users.salesforce_id connects to opportunities, accounts, leads, cases via owner_salesforce_id
      - accounts.salesforce_id connects to opportunities via account_salesforce_id
      - Use JOINs to get user names instead of IDs

      Current app_type: #{app_type}
    SCHEMA
  end

  def execute_safe_query(sql)
    cleaned_sql = sql.strip.downcase
    unless cleaned_sql.start_with?("select") || cleaned_sql.start_with?("with")
      raise "Only SELECT queries are allowed"
    end

    dangerous_patterns = [
      /\b(drop|delete|insert|alter|create|truncate)\s+/i,
      /;\s*(drop|delete|insert|alter|create|truncate)/i,
      /\bupdate\s+\w+\s+set\b/i
    ]

    if dangerous_patterns.any? { |pattern| sql.match?(pattern) }
      raise "Query contains prohibited SQL commands"
    end

    ActiveRecord::Base.connection.execute("SET statement_timeout = 15000")
    result = ActiveRecord::Base.connection.exec_query(sql)
    result.to_a
  end

  def handle_conversational_query(user_query, app_type, chat_service)
    conversation_context = chat_service&.build_context_for_prompt(app_type) || ""

    conversational_prompt = build_conversational_prompt(user_query, app_type, conversation_context)

    ai_response = call_bedrock_api_conversational(conversational_prompt)

    chat_service&.add_conversational_exchange(user_query, ai_response)

    {
      success: true,
      user_query: user_query,
      description: "AI Assistant Response",
      chart_type: "text",
      response: ai_response,
      processing_info: {
        model_used: MODEL_CONFIG[:model_id],
        context_used: conversation_context.present?,
        query_type: "conversational"
      }
    }
  rescue => e
    Rails.logger.error "Conversational AI Error: #{e.message}"
    { error: "Sorry, I couldn't process your question. Please try rephrasing it." }
  end

  def build_conversational_prompt(user_query, app_type, conversation_context)
    app_display_name = app_type == "pioneer" ? "Pioneer" : "Legacy"

    prompt_parts = []

    if conversation_context.present?
      prompt_parts << conversation_context
      prompt_parts << ""
    end

    prompt_parts << <<~PROMPT
      You are an AI assistant for a Salesforce analytics dashboard for the #{app_display_name} sales team.

      The user is asking for advice or having a conversation about their sales team management and Salesforce processes.
      Provide helpful, actionable advice based on sales and CRM best practices.

      Keep responses concise but informative (2-4 sentences).
      Focus on practical steps and recommendations for sales performance, pipeline management, and customer success.

      User question: #{user_query}
    PROMPT

    prompt_parts.join("\n")
  end

  def call_bedrock_api_conversational(prompt)
    client = initialize_bedrock_client

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 300,
      temperature: 0.3,
      system: "You are a helpful assistant for sales team management and Salesforce best practices. Provide concise, actionable advice.",
      messages: [ { role: "user", content: prompt } ]
    }

    response = client.invoke_model({
      model_id: MODEL_CONFIG[:model_id],
      body: request_body.to_json,
      content_type: "application/json"
    })

    response_body = JSON.parse(response.body.read)
    response_body.dig("content", 0, "text")&.strip
  end
end
