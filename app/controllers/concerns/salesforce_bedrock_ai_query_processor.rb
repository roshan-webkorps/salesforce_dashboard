# app/controllers/concerns/salesforce_bedrock_ai_query_processor.rb
module SalesforceBedrockAiQueryProcessor
  extend ActiveSupport::Concern

  MODEL_CONFIG = {
    model_id: "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
    max_tokens: 2000,
    temperature: 0.1
  }.freeze

  def process_salesforce_bedrock_ai_query(user_query, app_type = "legacy", chat_service = nil)
    begin
      Rails.logger.info "=== SALESFORCE BEDROCK QUERY PROCESSING ==="
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
        Rails.logger.info "User Query: #{user_query}"
        Rails.logger.info "Description: #{parsed_response['description']}"
        Rails.logger.info "Generated SQL: #{parsed_response['sql']}"

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
        Rails.logger.error "No SQL generated from AI response"
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
    query_lower = user_query.downcase

    conversational_patterns = [
      "how can i", "how do i", "what are best practices", "help me", "advice", "recommend",
      "should i", "what should", "how to", "tips for", "guide me", "explain how",
      "why is", "why are", "how can we", "what training", "how should i"
    ]

    return false if conversational_patterns.any? { |pattern| query_lower.include?(pattern) }

    # Data query keywords
    data_keywords = [
      "show", "list", "find", "get", "top", "most", "least", "how many", "count", "features",
      "opportunities", "accounts", "leads", "cases", "users", "sales", "revenue", "pipeline",
      "deals", "wins", "closed", "open", "conversion", "performance", "stats", "metrics",
      "reps", "customers", "prospects", "support", "tickets", "activity", "month", "year",
      "trend", "distribution", "by", "compare", "vs", "versus", "which", "what", "segment",
      "average time", "stuck in", "spend in"
    ]

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
      - CRITICAL: SQL must be on a SINGLE LINE with no line breaks or newlines
      - Replace all newlines in SQL with spaces to ensure valid JSON

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
      - ALWAYS exclude test data with "is_test_opportunity = false" when querying opportunities
      - For queries about actual revenue/performance, use "is_closed = true AND is_won = true"

      COMPARISON QUERY RULES:
      - For time comparisons like "January vs March" or "Q1 vs Q2", create AGGREGATE totals, not per-rep breakdowns
      - EXCEPTION: For rep performance comparisons like "this quarter vs last quarter", show individual rep data
      - NEVER reference column aliases in ORDER BY - use column numbers instead
      - For simple period comparisons, return just TWO rows: one for each time period
      - For rep performance comparisons, return multiple rows showing each rep's performance
      - Use UNION to combine separate time period queries into aggregate results
      - Format: SELECT 'Period Name' as period, COUNT/SUM as total

      NATURAL LANGUAGE TERMINOLOGY MAPPING:
      Map common business terms to database fields:
      - "revenue" = opportunities.amount (for closed won deals) OR accounts.annual_revenue
      - "deals" = opportunities
      - "reps" or "salespeople" = users (sales representatives)
      - "clients" or "customers" = accounts
      - "prospects" = leads
      - "tickets" = cases
      - "pipeline" = open opportunities (is_closed = false)
      - "closed business" or "won deals" = is_closed = true AND is_won = true
      - "lost deals" = is_closed = true AND is_won = false
      - "conversion" = leads where is_converted = true
      - "performance" = revenue, win rates, activity metrics
      - "activity" = count of opportunities, leads, etc.
      - "renewals" = opportunities where record_type_name = 'Renewal'
      - "new business" = opportunities where record_type_name = 'New Business'
      - "upgrades" = opportunities where record_type_name = 'Upgrade'
      - "renewal date" = renewal_date field (when renewal is due)
      - "close date" = close_date field (when deal closed)
      - "exclude test" or "real data" = is_test_opportunity = false

      DEFAULT TIME FRAME RULE - BE VERY SPECIFIC:

      APPLY 1-MONTH TIME FILTER for these query types:
      - "created this month", "new", "recent", "lately"
      - Activity-based: "opportunities created", "leads generated", "cases opened"
      - Any query about RECENT activity or CREATION

      DO NOT APPLY TIME FILTER for these query types:
      - "highest revenue" (looking for top performers all-time)
      - "by industry", "by segment", "distribution" (analyzing all existing data)
      - "all accounts", "total revenue", "best performing" (historical analysis)
      - Any query about EXISTING attributes or ALL-TIME rankings

      Examples:
      - "top accounts by revenue" = NO time filter (all accounts)
      - "accounts created this month" = YES time filter
      - "best sales reps" = NO time filter (all-time performance)
      - "recent opportunities" = YES time filter

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
        - Common stage names: 'Prospecting', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost'
        - Use ILIKE for stage matching to handle case variations: stage_name ILIKE '%negotiation%'
      9. For lead statuses, common values: 'New', 'Working', 'Qualified', 'Converted', 'Unqualified'
      10. For case priorities: 'High', 'Medium', 'Low', 'Critical'
      11. ALWAYS use ROUND() for percentages and rates: ROUND(calculation, 2) for 2 decimal places
      12. For date formatting in trends, use TO_CHAR(date, 'YYYY-MM') for month format
      13. NEVER use window functions like LAG, LEAD, or complex analytic functions
      14. For comparisons over time periods, use simple CASE statements or separate UNION queries
      LEAD CONVERSION LOGIC:
      - Lead conversion rates should use the lead.is_converted field, NOT opportunity counts
      - Do NOT try to link leads to opportunities unless there's explicit relationship data
      - For "lead-to-opportunity conversion", use: COUNT(CASE WHEN l.is_converted = true THEN 1 END) / COUNT(*)
      - Opportunities and leads are separate entities - don't assume correlation based on dates
      - If asked about "lead conversion", focus on leads.is_converted field only

      EXAMPLE RESPONSES:

      Query about ALL-TIME rankings (NO time filter):
      {"sql": "SELECT a.name, a.annual_revenue FROM accounts a JOIN users u ON a.owner_salesforce_id = u.salesforce_id WHERE a.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND a.annual_revenue > 0 ORDER BY a.annual_revenue DESC LIMIT 10", "description": "Top 10 accounts by annual revenue", "chart_type": "bar"}

      Query with proper rounding for rates:
      {"sql": "SELECT u.name, ROUND(COUNT(CASE WHEN o.is_won = true THEN 1 END) * 100.0 / COUNT(*), 2) as win_rate FROM users u JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id WHERE u.app_type = '#{app_type}' AND o.app_type = '#{app_type}' AND o.is_closed = true GROUP BY u.name ORDER BY 2 DESC", "description": "Sales rep win rates", "chart_type": "bar"}

      Query with date formatting for trends:
      {"sql": "SELECT TO_CHAR(o.close_date, 'Mon YYYY') as month, SUM(o.amount) as revenue FROM opportunities o WHERE o.app_type = '#{app_type}' AND o.is_closed = true AND o.is_won = true AND o.close_date >= NOW() - INTERVAL '6 months' GROUP BY TO_CHAR(o.close_date, 'Mon YYYY') ORDER BY MIN(o.close_date)", "description": "Monthly revenue trend", "chart_type": "line"}

      Query about renewals:
      {"sql": "SELECT u.name, SUM(o.amount) as renewal_revenue FROM opportunities o JOIN users u ON o.owner_salesforce_id = u.salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.record_type_name = 'Renewal' AND o.is_test_opportunity = false AND o.renewal_date >= NOW() - INTERVAL '1 month' GROUP BY u.name ORDER BY 2 DESC LIMIT 10", "description": "Top reps by renewal revenue this month", "chart_type": "bar"}

      Query filtering by opportunity type:
      {"sql": "SELECT o.record_type_name, COUNT(*) as deal_count, SUM(o.amount) as total_revenue FROM opportunities o WHERE o.app_type = '#{app_type}' AND o.is_closed = true AND o.is_won = true AND o.is_test_opportunity = false GROUP BY o.record_type_name ORDER BY 3 DESC", "description": "Revenue by opportunity type", "chart_type": "bar"}

      Query using renewal_date:
      {"sql": "SELECT u.name, COUNT(*) as renewals_due FROM opportunities o JOIN users u ON o.owner_salesforce_id = u.salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.record_type_name = 'Renewal' AND o.is_test_opportunity = false AND o.renewal_date BETWEEN NOW() AND NOW() + INTERVAL '30 days' GROUP BY u.name ORDER BY 2 DESC", "description": "Renewals due in next 30 days by rep", "chart_type": "bar"}

      Simple lead conversion (using is_converted field):
      {"sql": "SELECT u.name, ROUND(COUNT(CASE WHEN l.is_converted = true THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) as conversion_rate, COUNT(*) as total_leads FROM users u JOIN leads l ON u.salesforce_id = l.owner_salesforce_id WHERE u.app_type = '#{app_type}' AND l.app_type = '#{app_type}' GROUP BY u.name HAVING COUNT(*) >= 10 ORDER BY 2 DESC LIMIT 10", "description": "Lead conversion rates by sales rep", "chart_type": "bar"}

      Stage matching with case-insensitive search:
      {"sql": "SELECT o.name, u.name, EXTRACT(EPOCH FROM (NOW() - o.salesforce_created_date))/86400 as days_old FROM opportunities o JOIN users u ON o.owner_salesforce_id = u.salesforce_id WHERE o.app_type = '#{app_type}' AND u.app_type = '#{app_type}' AND o.stage_name ILIKE '%negotiation%' AND o.is_closed = false ORDER BY o.salesforce_created_date ASC LIMIT 10", "description": "Oldest deals stuck in negotiation", "chart_type": "table"}

      Rep performance comparison by quarter:
      {"sql": "SELECT u.name, 'Current Quarter' as period, SUM(CASE WHEN o.is_won = true THEN o.amount ELSE 0 END) as revenue FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id WHERE u.app_type = '#{app_type}' AND o.app_type = '#{app_type}' AND o.close_date >= DATE_TRUNC('quarter', CURRENT_DATE) GROUP BY u.name UNION SELECT u.name, 'Previous Quarter' as period, SUM(CASE WHEN o.is_won = true THEN o.amount ELSE 0 END) as revenue FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id WHERE u.app_type = '#{app_type}' AND o.app_type = '#{app_type}' AND o.close_date >= DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months' AND o.close_date < DATE_TRUNC('quarter', CURRENT_DATE) GROUP BY u.name ORDER BY 1, 2", "description": "Sales rep performance by quarter", "chart_type": "table"}

      CHART TYPE SELECTION RULES:
      - "bar" for rankings, top lists, comparisons between categories
      - "pie" for distributions, percentages, parts of a whole
      - "line" for trends over time, monthly/quarterly analysis, time series data
      - "table" for detailed lists, multiple columns of data

      CRITICAL: Any query with "trend", "over time", "monthly", "quarterly", "by month", "by quarter" MUST use chart_type: "line"

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
    extracted = extract_with_regex(cleaned_response)
    extracted || raise(JSON::ParserError, "Could not parse AI response")
  end

  def clean_response(response)
    cleaned = response.strip
    cleaned = cleaned[1...-1] if cleaned.start_with?('"') && cleaned.end_with?('"')

    cleaned = cleaned.gsub(/\r\n|\r|\n/, " ")  # Replace all types of newlines with spaces
    cleaned = cleaned.gsub(/\s+/, " ")         # Replace multiple spaces with single space
    cleaned = cleaned.gsub('\\"', '"')         # Unescape quotes
    cleaned = cleaned.gsub("\\\\", "\\")       # Unescape backslashes

    cleaned.strip
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
        - opportunity_type, lead_source, probability, expected_revenue, forecast_category
        - renewal_date (date when renewal is due)
        - is_test_opportunity (boolean - exclude test data)
        - record_type_name (type: New Business, Renewal, Upgrade, etc.)
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
  rescue => e
    Rails.logger.error "SQL execution error: #{e.message} | SQL: #{sql}"
    raise
  end

  def handle_conversational_query(user_query, app_type, chat_service)
    Rails.logger.info "=== HANDLING CONVERSATIONAL QUERY ==="
    conversation_context = chat_service&.build_context_for_prompt(app_type) || ""

    conversational_prompt = build_conversational_prompt(user_query, app_type, conversation_context)

    ai_response = call_bedrock_api_conversational(conversational_prompt)
    Rails.logger.info "Conversational AI Response: #{ai_response}"

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
    Rails.logger.error "=== CONVERSATIONAL AI ERROR ==="
    Rails.logger.error "Error: #{e.message}"
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
