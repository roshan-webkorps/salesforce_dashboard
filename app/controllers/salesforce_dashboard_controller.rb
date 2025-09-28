# app/controllers/salesforce_dashboard_controller.rb
class SalesforceDashboardController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :ai_query, :reset_chat ]

  def index
    # Renders the main React app
  end

  def api_data
    timeframe = params[:timeframe] || "24h"  # Default to 6 months
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
      case_priority_distribution: get_case_priority_distribution_data(timeframe_start)
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
    user_query = params[:query]
    app_type = params[:app_type] || "legacy"

    if user_query.blank?
      render json: { error: "Query cannot be empty" }, status: 400
      return
    end

    begin
      # Placeholder for AI functionality
      result = { response: "AI functionality will be implemented soon!" }
      render json: result
    rescue => e
      Rails.logger.error "AI Query Error: #{e.message}"
      render json: {
        error: "Sorry, I couldn't process your query. Please try rephrasing it."
      }, status: 500
    end
  end

  def reset_chat
    render json: { success: true, message: "Chat context reset" }
  end

  def health_check
    render json: {
      status: "ok",
      timestamp: Time.current,
      database: database_status,
      salesforce_connection: "configured"
    }
  end

  def chat_status
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
      24.hours.ago
    end
  end

  def database_status
    ActiveRecord::Base.connection.execute("SELECT 1")
    "connected"
  rescue
    "disconnected"
  end
end
