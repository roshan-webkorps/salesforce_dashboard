# app/controllers/concerns/salesforce_analytics.rb
module SalesforceAnalytics
  private

  def app_type
    "legacy"
  end

  # Scoped model helpers
  %w[opportunities accounts cases leads users].each do |model|
    define_method("scoped_#{model}") do
      model.classify.constantize.where(app_type: app_type)
    end
  end

  # ============================================================================
  # MAIN CHART METHODS
  # ============================================================================

  # 1. Opportunity Creation Trend
  def get_opportunity_creation_trend_data(since, timeframe = "24h")
    case timeframe
    when "24h" then build_hourly_opportunity_data(since)
    when "7d" then build_daily_opportunity_data(since)
    when "1m" then build_weekly_opportunity_data(since)
    when "6m" then build_monthly_opportunity_data(since)
    when "1y" then build_quarterly_data(since, :opportunities)
    else build_monthly_opportunity_data(since)
    end
  end

  # Keep backward compatibility
  def get_revenue_by_industry_data(since)
    get_opportunity_creation_trend_data(since, "24h")
  end

  # 2. Win Rate Analysis
  def get_win_rate_analysis_data(since)
    closed_opps = scoped_opportunities.where(is_closed: true).where("close_date >= ?", since)
    return default_chart_data(:pie, "No Data") if closed_opps.empty?

    won = closed_opps.where(is_won: true).count
    lost = closed_opps.where(is_won: false).count

    {
      labels: [ "Won", "Lost" ],
      datasets: [ {
        data: [ won, lost ],
        backgroundColor: [ "rgba(46, 204, 113, 0.6)", "rgba(231, 76, 60, 0.6)" ],
        borderColor: [ "rgba(46, 204, 113, 1)", "rgba(231, 76, 60, 1)" ],
        borderWidth: 1
      } ]
    }
  end

  # Keep backward compatibility
  def get_top_sales_reps_data(since)
    get_win_rate_analysis_data(since)
  end

  # 3. Account Acquisition vs Revenue
  def get_account_acquisition_revenue_data(since, timeframe)
    case timeframe
    when "24h" then build_hourly_account_revenue_data(since)
    when "7d" then build_daily_account_revenue_data(since)
    when "1m" then build_weekly_account_revenue_data(since)
    when "6m" then build_monthly_account_revenue_data(since)
    when "1y" then build_quarterly_data(since, :accounts_revenue)
    else build_monthly_account_revenue_data(since)
    end
  end

  # 4. Revenue Trend
  def get_revenue_trend_data(since, timeframe)
    case timeframe
    when "24h" then build_hourly_revenue_data(since)
    when "7d" then build_daily_revenue_data(since)
    when "1m" then build_weekly_revenue_data(since)
    when "6m" then build_monthly_revenue_data(since)
    when "1y" then build_quarterly_data(since, :revenue)
    else build_monthly_revenue_data(since)
    end
  end

  # 5-10. Other single model metrics
  def get_pipeline_health_data(since)
    data = scoped_opportunities.where(is_closed: false).where("salesforce_created_date >= ?", since).group(:stage_name).count
    return default_chart_data(:bar, "No Data") if data.empty?
    build_chart_data(:bar, data.to_a, "Opportunities")
  end

  def get_deal_size_distribution_data(since)
    won_opps = scoped_opportunities.where(is_won: true).where("close_date >= ?", since).where.not(amount: nil)
    return default_chart_data(:bar, "No Data") if won_opps.empty?

    ranges = {
      "Small (< $5K)" => won_opps.where("amount < 5000").count,
      "Medium ($5K - $25K)" => won_opps.where("amount >= 5000 AND amount < 25000").count,
      "Large ($25K - $100K)" => won_opps.where("amount >= 25000 AND amount < 100000").count,
      "Enterprise (> $100K)" => won_opps.where("amount >= 100000").count
    }.select { |_, count| count > 0 }

    return default_chart_data(:bar, "No Data") if ranges.empty?
    build_chart_data(:bar, ranges.to_a, "Number of Deals")
  end

  def get_lead_source_performance_data(since)
    data = scoped_leads.where("salesforce_created_date >= ?", since).where.not(lead_source: [ nil, "", "Unknown" ]).group(:lead_source).count.sort_by { |_, count| -count }.first(8)
    return default_chart_data(:pie, "No Data") if data.empty?
    build_chart_data(:pie, data, nil, hide_legend: true)
  end

  def get_account_segment_distribution_data(since)
    data = scoped_accounts.where("salesforce_created_date >= ?", since).where.not(segment: [ nil, "", "Unknown" ]).group(:segment).count
    return default_chart_data(:pie, "No Data") if data.empty?
    build_chart_data(:pie, data.to_a)
  end

  def get_lead_status_funnel_data(since)
    data = scoped_leads.where("salesforce_created_date >= ?", since).group(:status).count
    return default_chart_data(:bar, "No Data") if data.empty?
    build_chart_data(:bar, data.to_a, "Leads")
  end

  def get_case_priority_distribution_data(since)
    data = scoped_cases.where(status: "Open").where("salesforce_created_date >= ?", since).group(:priority).count
    return default_chart_data(:pie, "No Data") if data.empty?
    build_chart_data(:pie, data.to_a, nil, priority_colors: true)
  end

  # ============================================================================
  # CONSOLIDATED QUARTERLY BUILDER
  # ============================================================================

  def build_quarterly_data(since, type)
    current_date = Time.current
    current_quarter = ((current_date.month - 1) / 3) + 1
    current_year = current_date.year
    quarters_data = []

    # Set minimum quarter to Q4 2024 (your data start point)
    min_year = 2024
    min_quarter = 4

    # Start from current quarter and work backwards to find completed quarters
    year = current_year
    quarter = current_quarter

    while quarters_data.size < 4
      # Move to previous quarter
      quarter -= 1
      if quarter < 1
        quarter = 4
        year -= 1
      end

      # Stop if we've reached before Q4 2024
      break if year < min_year || (year == min_year && quarter < min_quarter)

      quarter_start = Date.new(year, (quarter - 1) * 3 + 1, 1).beginning_of_quarter
      quarter_end = Date.new(year, (quarter - 1) * 3 + 1, 1).end_of_quarter

      case type
      when :opportunities
        count = scoped_opportunities.where(salesforce_created_date: quarter_start..quarter_end).count
        quarters_data.unshift([ "Q#{quarter} #{year}", count ])
      when :revenue
        revenue = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: quarter_start..quarter_end).sum(:amount) || 0
        quarters_data.unshift([ "Q#{quarter} #{year}", revenue ])
      when :accounts_revenue
        accounts = scoped_accounts.where(salesforce_created_date: quarter_start..quarter_end).count
        revenue = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: quarter_start..quarter_end).sum(:amount) || 0
        quarters_data.unshift([ "Q#{quarter} #{year}", accounts, revenue ])
      end
    end

    return default_chart_data(:line, "No Data") if quarters_data.empty?

    labels = quarters_data.map(&:first)

    case type
    when :opportunities
      build_opportunity_creation_chart(labels, quarters_data.map(&:last), "Quarterly")
    when :revenue
      {
        labels: labels,
        datasets: [ {
          label: "Revenue ($)",
          data: quarters_data.map(&:last),
          borderColor: "rgba(46, 204, 113, 1)",
          backgroundColor: "rgba(46, 204, 113, 0.1)",
          borderWidth: 2,
          fill: true,
          tension: 0.4
        } ]
      }
    when :accounts_revenue
      {
        labels: labels,
        datasets: [
          {
            label: "New Accounts",
            data: quarters_data.map { |q| q[1] },
            borderColor: "rgba(52, 152, 219, 1)",
            backgroundColor: "rgba(52, 152, 219, 0.1)",
            yAxisID: "y"
          },
          {
            label: "Revenue ($)",
            data: quarters_data.map { |q| q[2] },
            borderColor: "rgba(46, 204, 113, 1)",
            backgroundColor: "rgba(46, 204, 113, 0.1)",
            yAxisID: "y1"
          }
        ]
      }
    end
  end

  # ============================================================================
  # UTILITY METHODS
  # ============================================================================

  def build_monthly_opportunity_data(since)
    data = []
    6.times do |i|
      month = since + i.months
      next if month.beginning_of_month > Time.current
      count = scoped_opportunities.where(salesforce_created_date: month.beginning_of_month..month.end_of_month).count
      data << [ month.strftime("%b %Y"), count ]
    end
    return default_chart_data(:line, "No Data") if data.empty?
    build_opportunity_creation_chart(data.map(&:first), data.map(&:last), "Monthly")
  end

  def build_opportunity_creation_chart(labels, data, period)
    {
      labels: labels,
      datasets: [ {
        label: "New Opportunities Created",
        data: data,
        borderColor: "rgba(52, 152, 219, 1)",
        backgroundColor: "rgba(52, 152, 219, 0.1)",
        borderWidth: 2,
        fill: true,
        tension: 0.4
      } ]
    }
  end

  def build_chart_data(type, data, label = nil, single_color: nil, priority_colors: false, hide_legend: false)
    labels = data.map { |row| row[0].present? ? row[0] : "Unknown" }
    values = data.map { |row| row[1].to_f }

    colors = if single_color
      Array.new(labels.size, color_map[single_color])
    elsif priority_colors
      priority_color_array(labels)
    else
      generate_colors(labels.size)
    end

    dataset = { data: values, backgroundColor: colors, borderColor: colors.map { |c| c.gsub("0.6", "1") }, borderWidth: 1 }
    dataset[:label] = label if label && type != :pie

    chart_options = { labels: labels, datasets: [ dataset ] }
    chart_options[:options] = { plugins: { legend: { display: false } } } if hide_legend
    chart_options
  end

  def default_chart_data(type, label)
    case type
    when :pie then { labels: [ label ], datasets: [ { data: [ 1 ], backgroundColor: [ "rgba(52, 152, 219, 0.6)" ] } ] }
    when :bar then { labels: [ label ], datasets: [ { label: "Data", data: [ 0 ], backgroundColor: "rgba(52, 152, 219, 0.6)" } ] }
    when :line then { labels: [ label ], datasets: [ { label: "Data", data: [ 0 ], borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)" } ] }
    end
  end

  def generate_colors(count)
    base_colors = %w[rgba(52,152,219,0.6) rgba(46,204,113,0.6) rgba(241,196,15,0.6) rgba(231,76,60,0.6) rgba(155,89,182,0.6) rgba(230,126,34,0.6) rgba(26,188,156,0.6) rgba(149,165,166,0.6)]
    (0...count).map { |i| base_colors[i % base_colors.length] }
  end

  def color_map
    { "green" => "rgba(46, 204, 113, 0.6)", "blue" => "rgba(52, 152, 219, 0.6)", "red" => "rgba(231, 76, 60, 0.6)", "yellow" => "rgba(241, 196, 15, 0.6)" }
  end

  def priority_color_array(labels)
    labels.map do |label|
      case label.to_s.downcase
      when /high/ then "rgba(231, 76, 60, 0.6)"
      when /medium/ then "rgba(241, 196, 15, 0.6)"
      when /low/ then "rgba(46, 204, 113, 0.6)"
      else "rgba(155, 89, 182, 0.6)"
      end
    end
  end

  def build_monthly_account_revenue_data(since)
    data = []
    account_counts = []
    revenue_amounts = []

    6.times do |i|
      month = since + i.months
      next if month.beginning_of_month > Time.current

      account_count = scoped_accounts.where(
        salesforce_created_date: month.beginning_of_month..month.end_of_month
      ).count

      revenue_amount = scoped_opportunities.where(is_won: true, is_closed: true)
                                          .where(close_date: month.beginning_of_month..month.end_of_month)
                                          .sum(:amount) || 0

      data << month.strftime("%b %Y")
      account_counts << account_count
      revenue_amounts << revenue_amount
    end

    return default_chart_data(:line, "No Data") if data.empty?

    {
      labels: data,
      datasets: [
        {
          label: "New Accounts",
          data: account_counts,
          borderColor: "rgba(52, 152, 219, 1)",
          backgroundColor: "rgba(52, 152, 219, 0.1)",
          yAxisID: "y"
        },
        {
          label: "Revenue ($)",
          data: revenue_amounts,
          borderColor: "rgba(46, 204, 113, 1)",
          backgroundColor: "rgba(46, 204, 113, 0.1)",
          yAxisID: "y1"
        }
      ]
    }
  end

  def build_monthly_revenue_data(since)
    data = []
    revenue_amounts = []

    6.times do |i|
      month = since + i.months
      next if month.beginning_of_month > Time.current

      revenue = scoped_opportunities.where(is_won: true, is_closed: true)
                                   .where(close_date: month.beginning_of_month..month.end_of_month)
                                   .sum(:amount) || 0

      data << month.strftime("%b %Y")
      revenue_amounts << revenue
    end

    return default_chart_data(:line, "No Data") if data.empty?

    {
      labels: data,
      datasets: [ {
        label: "Revenue ($)",
        data: revenue_amounts,
        borderColor: "rgba(46, 204, 113, 1)",
        backgroundColor: "rgba(46, 204, 113, 0.1)",
        borderWidth: 2,
        fill: true,
        tension: 0.4
      } ]
    }
  end

  def build_hourly_opportunity_data(since)
    labels = (0...24).map { |i| "#{i}:00" }
    data = Array.new(24, 0)

    scoped_opportunities.where("salesforce_created_date >= ?", since).each do |opp|
      next unless opp.salesforce_created_date
      hour = opp.salesforce_created_date.hour
      data[hour] += 1
    end

    build_opportunity_creation_chart(labels, data, "Hourly")
  end

  def build_hourly_account_revenue_data(since)
    labels = (0...24).map { |i| "#{i}:00" }
    account_counts = Array.new(24, 0)
    revenue_amounts = Array.new(24, 0)

    scoped_accounts.where("salesforce_created_date >= ?", since).each do |account|
      next unless account.salesforce_created_date
      hour = account.salesforce_created_date.hour
      account_counts[hour] += 1
    end

    scoped_opportunities.where(is_won: true, is_closed: true).where("close_date >= ?", since).each do |opp|
      next unless opp.close_date && opp.amount
      datetime = opp.close_date.is_a?(Date) ? opp.salesforce_created_date : opp.close_date
      next unless datetime&.respond_to?(:hour)
      hour = datetime.hour
      revenue_amounts[hour] += opp.amount
    end

    {
      labels: labels,
      datasets: [
        { label: "New Accounts", data: account_counts, borderColor: "rgba(52, 152, 219, 1)", backgroundColor: "rgba(52, 152, 219, 0.1)", yAxisID: "y" },
        { label: "Revenue ($)", data: revenue_amounts, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", yAxisID: "y1" }
      ]
    }
  end

  def build_hourly_revenue_data(since)
    labels = (0...24).map { |i| "#{i}:00" }
    data = Array.new(24, 0)

    scoped_opportunities.where(is_won: true, is_closed: true).where("close_date >= ?", since).each do |opp|
      next unless opp.close_date && opp.amount
      datetime = opp.close_date.is_a?(Date) ? opp.salesforce_created_date : opp.close_date
      next unless datetime&.respond_to?(:hour)
      hour = datetime.hour
      data[hour] += opp.amount
    end

    { labels: labels, datasets: [ { label: "Revenue ($)", data: data, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", borderWidth: 2, fill: true, tension: 0.4 } ] }
  end

  def build_daily_opportunity_data(since)
    labels = (0...7).map { |i| (since.to_date + i.days).strftime("%a %m/%d") }
    data = Array.new(7, 0)

    scoped_opportunities.where("salesforce_created_date >= ?", since).each do |opp|
      next unless opp.salesforce_created_date
      days = (opp.salesforce_created_date.to_date - since.to_date).to_i
      data[days] += 1 if days >= 0 && days < 7
    end

    build_opportunity_creation_chart(labels, data, "Daily")
  end

  def build_daily_account_revenue_data(since)
    labels = (0...7).map { |i| (since.to_date + i.days).strftime("%a %m/%d") }
    account_counts = Array.new(7, 0)
    revenue_amounts = Array.new(7, 0)

    7.times do |i|
      date = since.to_date + i.days
      account_counts[i] = scoped_accounts.where(salesforce_created_date: date.beginning_of_day..date.end_of_day).count
      revenue_amounts[i] = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: date.beginning_of_day..date.end_of_day).sum(:amount) || 0
    end

    {
      labels: labels,
      datasets: [
        { label: "New Accounts", data: account_counts, borderColor: "rgba(52, 152, 219, 1)", backgroundColor: "rgba(52, 152, 219, 0.1)", yAxisID: "y" },
        { label: "Revenue ($)", data: revenue_amounts, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", yAxisID: "y1" }
      ]
    }
  end

  def build_daily_revenue_data(since)
    labels = (0...7).map { |i| (since.to_date + i.days).strftime("%a %m/%d") }
    data = Array.new(7, 0)

    7.times do |i|
      date = since.to_date + i.days
      data[i] = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: date.beginning_of_day..date.end_of_day).sum(:amount) || 0
    end

    { labels: labels, datasets: [ { label: "Revenue ($)", data: data, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", borderWidth: 2, fill: true, tension: 0.4 } ] }
  end

  def build_weekly_opportunity_data(since)
    labels = (1..4).map { |i| "Week #{i}" }
    data = Array.new(4, 0)

    scoped_opportunities.where("salesforce_created_date >= ?", since).each do |opp|
      next unless opp.salesforce_created_date
      week = ((opp.salesforce_created_date.to_date - since.to_date).to_i / 7)
      data[week] += 1 if week >= 0 && week < 4
    end

    build_opportunity_creation_chart(labels, data, "Weekly")
  end

  def build_weekly_account_revenue_data(since)
    labels = (1..4).map { |i| "Week #{i}" }
    account_counts = Array.new(4, 0)
    revenue_amounts = Array.new(4, 0)

    4.times do |week|
      week_start = since + (week * 7).days
      week_end = week_start + 6.days
      account_counts[week] = scoped_accounts.where(salesforce_created_date: week_start..week_end).count
      revenue_amounts[week] = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: week_start..week_end).sum(:amount) || 0
    end

    {
      labels: labels,
      datasets: [
        { label: "New Accounts", data: account_counts, borderColor: "rgba(52, 152, 219, 1)", backgroundColor: "rgba(52, 152, 219, 0.1)", yAxisID: "y" },
        { label: "Revenue ($)", data: revenue_amounts, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", yAxisID: "y1" }
      ]
    }
  end

  def build_weekly_revenue_data(since)
    labels = (1..4).map { |i| "Week #{i}" }
    data = Array.new(4, 0)

    4.times do |week|
      week_start = since + (week * 7).days
      week_end = week_start + 6.days
      data[week] = scoped_opportunities.where(is_won: true, is_closed: true).where(close_date: week_start..week_end).sum(:amount) || 0
    end

    { labels: labels, datasets: [ { label: "Revenue ($)", data: data, borderColor: "rgba(46, 204, 113, 1)", backgroundColor: "rgba(46, 204, 113, 0.1)", borderWidth: 2, fill: true, tension: 0.4 } ] }
  end
end
