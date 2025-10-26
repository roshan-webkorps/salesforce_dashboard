# app/services/salesforce_ai_query_processor_with_transcripts.rb
class SalesforceAiQueryProcessorWithTranscripts
  include SalesforceBedrockAiQueryProcessor

  def process_query_with_transcripts(user_query, app_type = "legacy", chat_service = nil)
    begin
      Rails.logger.info "=== SALESFORCE AI QUERY WITH TRANSCRIPTS ==="
      Rails.logger.info "User Query: #{user_query}"
      Rails.logger.info "App Type: #{app_type}"

      # Extract sales rep name from query BEFORE any processing
      rep_name_from_query = extract_rep_name_from_query(user_query)
      Rails.logger.info "Extracted sales rep from query: #{rep_name_from_query}" if rep_name_from_query

      # Extract time period and search transcripts
      days = extract_time_period_from_ai(user_query)
      date_from = days ? days.days.ago.to_date : nil

      # Build context from conversation history
      conversation_context = chat_service&.build_context_for_prompt(app_type) || ""

      # CALL 1: Generate SQL from user query
      sql_generation_response = generate_sql_from_query(
        user_query,
        app_type,
        conversation_context,
        []  # No transcripts yet
      )

      parsed_response = parse_ai_response(sql_generation_response)

      transcript_query = parsed_response["transcript_query"] || user_query
      Rails.logger.info "Transcript search query: #{transcript_query}"

      transcript_chunks = SalesforceTranscriptSearchService.search(
        transcript_query,
        limit: 15,
        source: "salesforce",
        date_from: date_from
      )

      Rails.logger.info "Found #{transcript_chunks.length} transcript chunks"

      # Execute SQL if generated
      unless parsed_response["sql"].present?
        # If no SQL, treat as conversational query
        return handle_conversational_query(
          user_query,
          app_type,
          chat_service,
          conversation_context,
          transcript_chunks
        )
      end

      # Execute the SQL
      sql_results = execute_safe_query(parsed_response["sql"])

      if sql_results.empty?
        return {
          success: false,
          error: "No data found matching your query.",
          user_query: user_query
        }
      end

      # CALL 2: Generate final response with actual data
      # Pass the original rep name for transcript filtering
      final_response = generate_final_response_with_data(
        user_query,
        sql_results,
        transcript_chunks,
        app_type,
        rep_name_from_query  # NEW: Pass original name
      )

      # Store the exchange
      chat_service&.add_exchange(
        user_query: user_query,
        sql_query: parsed_response["sql"],
        sql_results: sql_results,
        ai_response: final_response
      )

      {
        success: true,
        user_query: user_query,
        description: parsed_response["description"] || "Query Results",
        summary: final_response,
        raw_results: sql_results,
        sql_executed: parsed_response["sql"],
        transcript_chunks_used: transcript_chunks.length,
        processing_info: {
          model_used: MODEL_CONFIG[:model_id],
          transcripts_used: transcript_chunks.any?,
          date_filter: date_from
        }
      }

    rescue => e
      Rails.logger.error "Salesforce AI Query with Transcripts Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      {
        success: false,
        error: "Sorry, I couldn't process your query. Please try rephrasing it.",
        user_query: user_query
      }
    end
  end

  private

  # Extract sales rep name from the original query
  def extract_rep_name_from_query(query)
    # Match capitalized names (like "Sarah", "John Smith", etc.)
    names = query.scan(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b/)

    # Filter out common words that aren't names
    common_words = %w[Salesforce Otter September October November December January February March April May June July August How What Where When Which Who Why]
    names = names.reject { |name| common_words.include?(name) }

    # Return first valid name found
    names.first
  end

  # Extract sales rep name from SQL results (fallback)
  def extract_rep_name_from_results(sql_results)
    return nil unless sql_results.is_a?(Array) && sql_results.any?
    return nil unless sql_results.first.is_a?(Hash)

    first_row = sql_results.first

    # Try different possible column names
    first_row["name"] || first_row["sales_rep_name"] || first_row["rep_name"]
  end

  # CALL 1: Generate SQL from user query with context
  def generate_sql_from_query(user_query, app_type, conversation_context, _unused = nil)
    client = initialize_bedrock_client
    schema_context = get_salesforce_database_context(app_type)

    system_prompt = build_sql_generation_prompt(
      app_type,
      schema_context,
      conversation_context,
      []
    )

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 500,
      temperature: 0.0,
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
    Rails.logger.error "SQL generation error: #{e.message}"
    raise
  end

  # CALL 2: Generate final natural language response with data
  def generate_final_response_with_data(user_query, sql_results, transcript_chunks, app_type, rep_name_from_query = nil)
    client = initialize_bedrock_client

    # Filter transcripts using the ORIGINAL rep name from query
    filtered_transcripts = filter_transcripts_by_rep(
      transcript_chunks,
      rep_name_from_query || extract_rep_name_from_results(sql_results)
    )

    system_prompt = build_response_generation_prompt(app_type, sql_results)

    user_prompt = build_response_user_prompt(
      user_query,
      sql_results,
      filtered_transcripts
    )

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 2000,
      temperature: 0.3,
      system: system_prompt,
      messages: [ { role: "user", content: user_prompt } ]
    }

    response = client.invoke_model({
      model_id: MODEL_CONFIG[:model_id],
      body: request_body.to_json,
      content_type: "application/json"
    })

    response_body = JSON.parse(response.body.read)
    ai_response = response_body.dig("content", 0, "text")&.strip

    # Clean up response
    clean_ai_response(ai_response)
  rescue => e
    Rails.logger.error "Response generation error: #{e.message}"
    "I found the data but had trouble analyzing it. Please try rephrasing your question."
  end

  # Build system prompt for SQL generation (CALL 1)
  def build_sql_generation_prompt(app_type, schema_context, conversation_context, transcript_chunks)
    app_display_name = app_type == "legacy" ? "Legacy" : "Pioneer"
    prompt_parts = []

    # Add conversation context if available
    if conversation_context.present?
      prompt_parts << conversation_context
      prompt_parts << ""
    end

    prompt_parts << <<~SQL_PROMPT
      You are a SQL query generator for a #{app_display_name} Salesforce sales analytics database.

      DATABASE SCHEMA:
      #{schema_context}

      CRITICAL RULES:
      1. Response MUST be valid JSON: {"sql":"SELECT...","description":"Brief description","transcript_query":"search terms for meeting transcripts"}
      2. FORBIDDEN: WITH clauses, CTEs, CASE WHEN, ROUND, LEAST, GREATEST, nested subqueries
      3. ONLY use: SELECT, FROM, LEFT JOIN, WHERE, GROUP BY, ORDER BY, LIMIT, HAVING
      4. ALWAYS filter: app_type = '#{app_type}' on ALL tables
      5. ALWAYS exclude test data: is_test_opportunity = false when querying opportunities table
      6. For won/closed revenue: ALWAYS use "o.is_closed = true AND o.is_won = true"
      7. Use COALESCE for nullable aggregations
      8. Use ILIKE for case-insensitive name matching
      9. For money calculations, cast to avoid scientific notation: SUM(o.amount)::numeric
      10. For ranking queries, use HAVING to filter out zero/null values and ORDER BY with NULLS LAST

      CRITICAL DATE FIELD RULES:
      - For "performance", "revenue", "closed deals", "won deals" queries: use close_date field
      - For "created", "new", "generated opportunities" queries: use salesforce_created_date field
      - For "pipeline", "open opportunities": no date filter needed (use is_closed = false)
      - NEVER filter won deals by salesforce_created_date - always use close_date

      TIME FILTER RULES:
      - NO TIME FILTER if query says: "top", "best", "most", "highest", "lowest" WITHOUT time words
      - ADD TIME FILTER (1 month default) if query mentions: "this month", "last month", "recent", "in last X", "this year"
      - Exception: Performance queries with explicit time mention should filter by close_date

      Examples:
      - "top 5 reps by revenue" = NO time filter (all-time)
      - "top 5 reps this month" = close_date >= NOW() - INTERVAL '1 month'
      - "Brent's performance last month" = close_date >= NOW() - INTERVAL '1 month'
      - "new opportunities this month" = salesforce_created_date >= NOW() - INTERVAL '1 month'

      TRANSCRIPT SEARCH:
      - Include a "transcript_query" field with ONLY the person's first name for person-specific queries
      - For sales rep queries: use ONLY their first name (e.g., "sarah" not "sarah performance")
      - For general queries: use 1-2 topic keywords (e.g., "pipeline", "deals")

      EXAMPLE QUERIES:

      1. Sales rep performance with time filter (last month - use close_date):
      {
        "sql": "SELECT u.name as sales_rep, COUNT(DISTINCT o.id) as total_opportunities, COUNT(DISTINCT CASE WHEN o.is_closed = true AND o.is_won = true THEN o.id END) as won_deals, SUM(CASE WHEN o.is_closed = true AND o.is_won = true THEN o.amount ELSE 0 END)::numeric as won_revenue, SUM(CASE WHEN o.is_closed = false THEN o.amount ELSE 0 END)::numeric as open_pipeline FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id AND o.app_type='#{app_type}' AND o.is_test_opportunity = false AND o.close_date >= NOW() - INTERVAL '1 month' WHERE u.app_type = '#{app_type}' AND u.name ILIKE '%Brent%' GROUP BY u.name",
        "description": "Brent's performance metrics for last month",
        "transcript_query": "brent"
      }

      2. Top sales reps by revenue (ALL-TIME - no date filter):
      {
        "sql": "SELECT u.name as sales_rep, COUNT(o.id) as won_deals, SUM(o.amount)::numeric as total_revenue FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id AND o.app_type = '#{app_type}' AND o.is_closed = true AND o.is_won = true AND o.is_test_opportunity = false WHERE u.app_type = '#{app_type}' GROUP BY u.name HAVING SUM(o.amount) > 0 ORDER BY total_revenue DESC NULLS LAST LIMIT 5",
        "description": "Top 5 sales reps by total revenue (all-time)",
        "transcript_query": "sales revenue"
      }

      3. Pipeline value (open opportunities - no date filter needed):
      {
        "sql": "SELECT u.name as sales_rep, COUNT(o.id) as open_opportunities, SUM(o.amount)::numeric as pipeline_value FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id AND o.app_type='#{app_type}' AND o.is_closed = false AND o.is_test_opportunity = false WHERE u.app_type = '#{app_type}' AND u.name ILIKE '%Brent%' GROUP BY u.name",
        "description": "Brent's current pipeline value",
        "transcript_query": "brent"
      }

      4. New opportunities created this month (use salesforce_created_date):
      {
        "sql": "SELECT u.name as sales_rep, COUNT(o.id) as new_opportunities FROM users u LEFT JOIN opportunities o ON u.salesforce_id = o.owner_salesforce_id AND o.app_type='#{app_type}' AND o.is_test_opportunity = false AND o.salesforce_created_date >= NOW() - INTERVAL '1 month' WHERE u.app_type = '#{app_type}' GROUP BY u.name ORDER BY new_opportunities DESC LIMIT 10",
        "description": "Top 10 reps by new opportunities created this month",
        "transcript_query": "new opportunities"
      }

      Respond with ONLY the JSON object. Nothing before {, nothing after }.
    SQL_PROMPT

    prompt_parts.join("\n")
  end

  # Build system prompt for response generation (CALL 2)
  def build_response_generation_prompt(app_type, sql_results)
    app_display_name = app_type == "legacy" ? "Legacy" : "Pioneer"

    <<~RESPONSE_PROMPT
      You are a performance analyst for the #{app_display_name} Salesforce sales team.

      Your job is to analyze data and provide clear, actionable insights.

      WRITING STYLE:
      - Write in short, focused paragraphs (2-4 sentences each)
      - Separate different topics with a blank line between paragraphs
      - Maximum 3 paragraphs total
      - Use bold markdown **like this** to highlight key metrics and achievements
      - Be concise and scannable - prioritize clarity over comprehensiveness
      - Focus on the most important insights only

      ANALYSIS GUIDELINES:
      - Combine quantitative metrics with qualitative context from meetings
      - Focus on strengths, achievements, and positive contributions
      - Frame any areas for improvement constructively and supportively
      - Lead with accomplishments before mentioning growth areas
      - Use appreciative language and highlight specific positive evidence
      - Keep tone warm, encouraging, and professional
      - Default to optimistic interpretation when data is ambiguous

      TONE REQUIREMENTS:
      - Maintain a predominantly positive and encouraging tone (80% positive, 20% constructive)
      - Start with accomplishments and strong points
      - Frame challenges as "opportunities for growth" not "weaknesses"
      - End on an uplifting or forward-looking note
      - Keep it brief - if you can't fit it in 3 short paragraphs, it's not essential
      - Use phrases like "demonstrates", "shows capability", "actively contributing" rather than negative framing

      STRUCTURE:
      Paragraph 1: Key metrics and what they show (2-3 sentences, use **bold** for numbers)
      Paragraph 2: Meeting insights and notable contributions (2-3 sentences)
      Paragraph 3: Growth opportunities or forward-looking statement (1-2 sentences)

      IMPORTANT:
      - Use ONLY the data provided to you
      - If data is incomplete, acknowledge limitations neutrally
      - Never invent or assume information not in the data
      - Reference specific numbers and meeting insights naturally
    RESPONSE_PROMPT
  end

  # Build user prompt for response generation (CALL 2)
  def build_response_user_prompt(user_query, sql_results, transcript_chunks)
    prompt_parts = []

    prompt_parts << "ORIGINAL QUESTION:"
    prompt_parts << user_query
    prompt_parts << ""

    prompt_parts << "DATA FROM DATABASE:"
    formatted_results = sql_results.map do |row|
      row.transform_values do |value|
        if value.is_a?(BigDecimal) || (value.is_a?(String) && value.match?(/e[+-]?\d+/i))
          value.to_f.round(2)
        else
          value
        end
      end
    end
    prompt_parts << JSON.pretty_generate(formatted_results)
    prompt_parts << ""

    if transcript_chunks.any?
      prompt_parts << "RELEVANT MEETING CONTEXT:"
      transcript_chunks.first(10).each_with_index do |chunk, i|
        meeting_date = chunk["meeting_date"] ? " (#{chunk['meeting_date']})" : ""
        prompt_parts << "Meeting #{i+1}#{meeting_date}:"
        prompt_parts << chunk["text"][0..600]
        prompt_parts << ""
      end
    else
      prompt_parts << "MEETING CONTEXT: No relevant meeting transcripts available."
      prompt_parts << ""
    end

    prompt_parts << "Generate a comprehensive response that answers the user's question using the data and meeting context provided."

    prompt_parts.join("\n")
  end

  # Filter transcripts by sales rep name from ORIGINAL QUERY
  def filter_transcripts_by_rep(transcript_chunks, rep_name)
    return transcript_chunks if rep_name.blank?

    # Use the actual name for filtering
    name_parts = rep_name.downcase.split
    name_variations = [
      rep_name.downcase,
      name_parts.first,  # First name only
      name_parts.last    # Last name only (if exists)
    ].compact.uniq

    Rails.logger.info "Filtering transcripts for: #{rep_name} (variations: #{name_variations.join(', ')})"

    filtered = transcript_chunks.select do |chunk|
      text = chunk["text"].to_s.downcase
      name_variations.any? { |variation| text.include?(variation) }
    end

    Rails.logger.info "Transcript filter: #{transcript_chunks.length} → #{filtered.length} chunks for '#{rep_name}'"

    # If no matches, return a few transcripts anyway (better than nothing)
    filtered.any? ? filtered : transcript_chunks.first(3)
  end

  # Handle conversational queries (no SQL needed)
  def handle_conversational_query(user_query, app_type, chat_service, conversation_context, transcript_chunks)
    client = initialize_bedrock_client

    system_prompt = build_response_generation_prompt(app_type, [])

    prompt_parts = []

    if conversation_context.present?
      prompt_parts << conversation_context
      prompt_parts << ""
    end

    if transcript_chunks.any?
      prompt_parts << "RELEVANT MEETING CONTEXT:"
      transcript_chunks.first(10).each_with_index do |chunk, i|
        meeting_date = chunk["meeting_date"] ? " (#{chunk['meeting_date']})" : ""
        prompt_parts << "Meeting #{i+1}#{meeting_date}:"
        prompt_parts << chunk["text"][0..400]
        prompt_parts << ""
      end
    end

    prompt_parts << "USER QUESTION:"
    prompt_parts << user_query
    prompt_parts << ""
    prompt_parts << "Provide a helpful, concise response based on sales best practices and any available context."

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 1000,
      temperature: 0.3,
      system: system_prompt,
      messages: [ { role: "user", content: prompt_parts.join("\n") } ]
    }

    response = client.invoke_model({
      model_id: MODEL_CONFIG[:model_id],
      body: request_body.to_json,
      content_type: "application/json"
    })

    response_body = JSON.parse(response.body.read)
    ai_response = response_body.dig("content", 0, "text")&.strip

    chat_service&.add_conversational_exchange(user_query, clean_ai_response(ai_response))

    {
      success: true,
      user_query: user_query,
      description: "AI Assistant Response",
      summary: clean_ai_response(ai_response),
      transcript_chunks_used: transcript_chunks.length,
      processing_info: {
        model_used: MODEL_CONFIG[:model_id],
        query_type: "conversational",
        transcripts_used: transcript_chunks.any?
      }
    }
  rescue => e
    Rails.logger.error "Conversational query error: #{e.message}"
    {
      success: false,
      error: "Sorry, I couldn't process your question. Please try rephrasing it.",
      user_query: user_query
    }
  end

  # Clean up AI response text
  def clean_ai_response(response)
    return "" unless response.present?

    # Remove quotes if wrapped
    cleaned = response.gsub(/^["']|["']$/, "").strip

    # Remove any "Note:" sections
    cleaned = cleaned.split(/\n\n?Note:/i).first&.strip || cleaned

    # Convert numbered lists to paragraphs if present
    if cleaned.match?(/^\d+\.\s/)
      Rails.logger.warn "AI returned numbered list - converting to paragraph"
      cleaned = cleaned.gsub(/^\d+\.\s+/, "").gsub(/\n+/, " ")
    end

    # Convert bullet lists to paragraphs if present
    if cleaned.match?(/^[•\-\*]\s/)
      Rails.logger.warn "AI returned bullet list - converting to paragraph"
      cleaned = cleaned.gsub(/^[•\-\*]\s+/, "").gsub(/\n+/, " ")
    end

    cleaned.strip
  end

  # Extract time period from query using AI
  def extract_time_period_from_ai(query)
    client = initialize_bedrock_client

    request_body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 10,
      temperature: 0.0,
      messages: [ {
        role: "user",
        content: "Extract time period as days from: '#{query}'. Examples: 'last week'→7, 'last month'→30, 'last 45 days'→45, 'all time'→null. Respond with ONLY the number or null."
      } ]
    }

    response = client.invoke_model({
      model_id: MODEL_CONFIG[:model_id],
      body: request_body.to_json,
      content_type: "application/json"
    })

    response_body = JSON.parse(response.body.read)
    ai_response = response_body.dig("content", 0, "text")&.strip

    return nil if ai_response == "null"
    ai_response.to_i > 0 ? ai_response.to_i : 30
  rescue => e
    Rails.logger.error "Time extraction error: #{e.message}"
    30  # Default to 30 days
  end
end
