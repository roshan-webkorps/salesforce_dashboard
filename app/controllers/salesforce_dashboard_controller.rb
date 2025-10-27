# app/controllers/salesforce_dashboard_controller.rb
class SalesforceDashboardController < ApplicationController
  include SalesforceBedrockAiQueryProcessor

  skip_before_action :verify_authenticity_token, only: [ :ai_query, :reset_chat ]

  before_action :initialize_chat_service, only: [ :ai_query, :reset_chat ]

  def index
    # Renders the main React app
  end

  def chat_home
    render layout: "chat"
  end

  def api_data
    session.delete(:chat_service) if request.get? && request.path == "/api/salesforce"

    timeframe = params[:timeframe] || "1m"  # Default to 1 month
    app_type = params[:app_type] || "legacy"  # Default to legacy
    timeframe_start = calculate_timeframe_start(timeframe)

    extend SalesforceAnalytics

    charts_data = {
      revenue_by_industry: get_opportunity_creation_trend_data(timeframe_start, timeframe),
      top_sales_reps: get_win_rate_analysis_data(timeframe_start),
      account_acquisition_revenue: get_account_acquisition_revenue_data(timeframe_start, timeframe),
      pipeline_health: get_pipeline_health_data(timeframe_start),
      deal_size_distribution: get_deal_size_distribution_data(timeframe_start),
      lead_source_performance: get_lead_source_performance_data(timeframe_start),
      revenue_trend: get_revenue_trend_data(timeframe_start, timeframe),
      account_segment_distribution: get_account_segment_distribution_data(timeframe_start),
      lead_status_funnel: get_lead_status_funnel_data(timeframe_start),
      case_priority_distribution: get_case_priority_distribution_data(timeframe_start),
      sales_rep_revenue_by_stage: get_sales_rep_revenue_by_stage_data(timeframe_start, timeframe),
      top_sales_reps_closed_won: get_top_sales_reps_closed_won_data(timeframe_start, timeframe),
      closed_won_by_type: get_closed_won_by_type_data(timeframe_start, timeframe)
    }

    render json: {
      timeframe: timeframe,
      app_type: app_type,
      message: "Optimized Salesforce Dashboard API is working!",
      charts_data: charts_data,
      summary: get_salesforce_summary_data(timeframe_start, app_type)
    }
  rescue => e
    Rails.logger.error "Dashboard API Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "Unable to load dashboard data",
      timeframe: timeframe,
      app_type: app_type,
      charts_data: {},
      summary: {}
    }, status: 500
  end

  def ai_query
    ip_address = request.remote_ip
    user_query = params[:query]
    app_type = params[:app_type] || "legacy"

    log_chat_prompt_history(ip_address, app_type, user_query)

    if user_query.blank?
      render json: { error: "Query cannot be empty" }, status: 400
      return
    end

    begin
      processor = SalesforceAiQueryProcessorWithTranscripts.new
      result = processor.process_query_with_transcripts(user_query, app_type, @chat_service)

      render json: result
    rescue => e
      Rails.logger.error "AI Query Error: #{e.message}"
      render json: {
        error: "Sorry, I couldn't process your query. Please try rephrasing it."
      }, status: 500
    end
  end

  def reset_chat
    session.delete(:chat_service)
    @chat_service = Ai::SalesforceChatService.new

    render json: { success: true, message: "Chat context reset" }
  end

  def health_check
    render json: {
      status: "ok",
      timestamp: Time.current,
      database: database_status,
      salesforce_connection: "configured",
      aws_bedrock: ENV["AWS_ACCESS_KEY_ID"].present? ? "configured" : "missing"
    }
  end

  def chat_status
    has_context = session[:chat_service].present? && !session[:chat_service].empty?
    render json: { has_context: has_context }
  end

  private

  def get_salesforce_summary_data(timeframe_start, app_type)
    extend SalesforceAnalytics

    {
      total_accounts: Account.where(app_type: app_type).count,
      total_sales_reps: User.where(app_type: app_type, is_active: true).count,
      total_open_opportunities: Opportunity.where(app_type: app_type, is_closed: false).count,
      total_revenue: Opportunity.where(app_type: app_type, is_closed: true, is_won: true)
                                .where(is_test_opportunity: false)
                                .where("close_date >= ?", timeframe_start)
                                .sum(:amount) || 0,
      total_cases: Case.where(app_type: app_type)
                      .where("salesforce_created_date >= ?", timeframe_start).count
    }
  end

  def calculate_timeframe_start(timeframe)
    case timeframe
    when "24h"
      24.hours.ago
    when "7d"
      7.days.ago
    when "1m"
      1.month.ago
    when "6m"
      6.months.ago
    when "1y"
      1.year.ago
    else
      24.hours.ago
    end
  end

  def log_chat_prompt_history(ip_address, app_type, prompt)
    ChatPromptHistory.find_or_create_by(ip_address: ip_address, prompt: prompt) do |record|
      record.app_type = app_type
    end
  end

  def database_status
    ActiveRecord::Base.connection.execute("SELECT 1")
    "connected"
  rescue
    "disconnected"
  end

  def initialize_chat_service
    if session[:chat_service] && !session[:chat_service].empty?
      @chat_service = deserialize_chat_service(session[:chat_service])
    else
      @chat_service = Ai::SalesforceChatService.new
    end
  rescue => e
    Rails.logger.error "Chat service initialization error: #{e.message}"
    @chat_service = Ai::SalesforceChatService.new
  end

  def serialize_chat_service(chat_service)
    context = chat_service.data_context || {}
    {
      sales_reps: (context[:sales_reps] || context["sales_reps"] || []).first(3),
      accounts: (context[:accounts] || context["accounts"] || []).first(3),
      opportunities: (context[:opportunities] || context["opportunities"] || []).first(3),
      leads: (context[:leads] || context["leads"] || []).first(3),
      cases: (context[:cases] || context["cases"] || []).first(3)
    }.compact
  end

  def deserialize_chat_service(serialized_data)
    chat_service = Ai::SalesforceChatService.new
    if serialized_data&.any?
      chat_service.instance_variable_set(:@data_context, serialized_data.symbolize_keys)
    end
    chat_service
  end

  after_action :update_chat_session, only: [ :ai_query ]

  def update_chat_session
    if @chat_service
      session[:chat_service] = serialize_chat_service(@chat_service)
    end
  end
end
