# app/controllers/salesforce_dashboard_controller.rb
class SalesforceDashboardController < ApplicationController
  # include BedrockAiQueryProcessor  # Add this when you implement AI chat

  skip_before_action :verify_authenticity_token, only: [ :ai_query, :reset_chat ]

  # Store chat services in session to maintain context during user session
  # before_action :initialize_chat_service, only: [:ai_query, :reset_chat]  # Add when implementing AI

  def index
    # Renders the main React app
  end

  def api_data
    # session.delete(:chat_service) if request.get? && request.path == "/api/salesforce"  # Add when implementing AI

    timeframe = params[:timeframe] || "6m"  # Default to 6 months for sales data
    app_type = params[:app_type] || "legacy"  # Default to legacy
    timeframe_start = calculate_timeframe_start(timeframe)

    # Extend with the Salesforce analytics module
    extend SalesforceAnalytics

    # Base charts for salesforce dashboard
    charts_data = {
      revenue_by_sales_rep: get_revenue_by_sales_rep_data(timeframe_start),
      sales_pipeline_by_stage: get_sales_pipeline_by_stage_data(timeframe_start),
      monthly_revenue_trend: get_monthly_revenue_trend_data(timeframe_start),
      revenue_by_industry: get_revenue_by_industry_data(timeframe_start),
      case_priority_distribution: get_case_priority_distribution_data(timeframe_start),
      account_revenue_distribution: get_account_revenue_distribution_data(timeframe_start)
    }

    render json: {
      timeframe: timeframe,
      app_type: app_type,
      message: "Salesforce Dashboard API is working!",
      charts_data: charts_data,
      summary: get_salesforce_summary_data(timeframe_start, app_type),
      sales_rep_stats: get_sales_rep_stats(timeframe_start),
      account_stats: get_account_stats(timeframe_start)
    }
  end

  # AI Query endpoint (implement later when adding AI chat)
  def ai_query
    user_query = params[:query]
    # app_type = params[:app_type] || "legacy"

    if user_query.blank?
      render json: { error: "Query cannot be empty" }, status: 400
      return
    end

    begin
      # Process query with chat context using the updated processor
      # result = process_bedrock_ai_query(user_query, app_type, @chat_service)

      # For now, return a placeholder response
      result = { response: "AI functionality will be implemented soon!" }

      render json: result
    rescue => e
      Rails.logger.error "AI Query Error: #{e.message}"
      render json: {
        error: "Sorry, I couldn't process your query. Please try rephrasing it."
      }, status: 500
    end
  end

  # New endpoint for resetting chat context
  def reset_chat
    # Clear chat context for new topic
    # session.delete(:chat_service)
    # @chat_service = Ai::ChatService.new

    render json: { success: true, message: "Chat context reset" }
  end

  def health_check
    render json: {
      status: "ok",
      timestamp: Time.current,
      database: database_status,
      salesforce_connection: "configured"  # Add actual salesforce connection check if needed
    }
  end

  def chat_status
    # has_context = session[:chat_service].present? && !session[:chat_service].empty?
    has_context = false  # Placeholder until AI is implemented
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
      6.months.ago  # Default to 6 months for sales data
    end
  end

  def database_status
    ActiveRecord::Base.connection.execute("SELECT 1")
    "connected"
  rescue
    "disconnected"
  end

  def get_sales_rep_stats(timeframe_start)
    User.where(is_active: true)
        .joins(:owned_opportunities)
        .where("opportunities.close_date >= ? AND opportunities.is_closed = ? AND opportunities.is_won = ?",
               timeframe_start, true, true)
        .group("users.id", "users.name")
        .order("SUM(opportunities.amount) DESC")
        .limit(10)
        .pluck("users.name", "SUM(opportunities.amount)")
        .map { |name, revenue| { name: name, revenue: revenue } }
  end

  def get_account_stats(timeframe_start)
    Account.joins(:opportunities)
           .where("opportunities.close_date >= ? AND opportunities.is_closed = ? AND opportunities.is_won = ?",
                  timeframe_start, true, true)
           .group("accounts.id", "accounts.name")
           .order("SUM(opportunities.amount) DESC")
           .limit(10)
           .pluck("accounts.name", "SUM(opportunities.amount)")
           .map { |name, revenue| { name: name, revenue: revenue } }
  end

  # Chat service management methods (implement when adding AI)
  # def initialize_chat_service
  #   if session[:chat_service] && !session[:chat_service].empty?
  #     @chat_service = deserialize_chat_service(session[:chat_service])
  #   else
  #     @chat_service = Ai::ChatService.new
  #   end
  # rescue => e
  #   Rails.logger.error "Chat service initialization error: #{e.message}"
  #   @chat_service = Ai::ChatService.new
  # end
end
