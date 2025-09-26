# app/controllers/concerns/salesforce_analytics.rb
module SalesforceAnalytics
  # include BaseAnalytics

  private

  def app_type
    "legacy" # or "pioneer" - you can change this based on your needs
  end

  # Helper methods that automatically filter by app_type
  def scoped_opportunities
    Opportunity.where(app_type: app_type)
  end

  def scoped_accounts
    Account.where(app_type: app_type)
  end

  def scoped_cases
    Case.where(app_type: app_type)
  end

  def scoped_leads
    Lead.where(app_type: app_type)
  end

  def scoped_users
    User.where(app_type: app_type)
  end

  # 1. Revenue by Sales Rep
  def get_revenue_by_sales_rep_data(since)
    won_opportunities = scoped_opportunities.includes(:owner)
                                           .where(is_closed: true, is_won: true)
                                           .where("close_date >= ?", since)

    if won_opportunities.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ {
          label: "Revenue",
          data: [ 0 ],
          backgroundColor: "rgba(52, 152, 219, 0.6)"
        } ]
      }
    end

    # Group by sales rep and sum revenue
    rep_revenue = {}
    won_opportunities.each do |opp|
      next unless opp.owner && opp.amount

      rep_name = opp.owner.name
      rep_revenue[rep_name] ||= 0
      rep_revenue[rep_name] += opp.amount
    end

    # Sort by revenue descending
    sorted_reps = rep_revenue.sort_by { |rep, revenue| -revenue }.to_h

    # Format for chart
    labels = sorted_reps.keys.map { |name| name.length > 12 ? "#{name[0...9]}..." : name }
    data = sorted_reps.values

    {
      labels: labels,
      datasets: [ {
        label: "Revenue ($)",
        data: data,
        backgroundColor: "rgba(46, 204, 113, 0.6)",
        borderColor: "rgba(46, 204, 113, 1)",
        borderWidth: 1
      } ]
    }
  end

  # 2. Sales Pipeline by Stage
  def get_sales_pipeline_by_stage_data(since)
    open_opportunities = scoped_opportunities.where(is_closed: false)
                                           .where("salesforce_created_date >= ?", since)

    if open_opportunities.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ {
          label: "Pipeline Value",
          data: [ 0 ],
          backgroundColor: "rgba(52, 152, 219, 0.6)"
        } ]
      }
    end

    # Group by stage and sum amounts
    stage_values = {}
    open_opportunities.each do |opp|
      stage = opp.stage_name.present? ? opp.stage_name : "Unknown Stage"
      amount = opp.amount || 0

      stage_values[stage] ||= 0
      stage_values[stage] += amount
    end

    # Sort stages in typical sales order (you can customize this)
    stage_order = [ "Prospecting", "Qualification", "Needs Analysis", "Value Proposition",
                   "Proposal/Price Quote", "Negotiation/Review", "Closed Won", "Closed Lost" ]

    sorted_stages = stage_values.keys.sort_by do |stage|
      index = stage_order.find_index(stage)
      index ? index : stage_order.length
    end

    colors = [
      "rgba(52, 152, 219, 0.6)",   # Blue
      "rgba(46, 204, 113, 0.6)",   # Green
      "rgba(241, 196, 15, 0.6)",   # Yellow
      "rgba(231, 76, 60, 0.6)",    # Red
      "rgba(155, 89, 182, 0.6)",   # Purple
      "rgba(230, 126, 34, 0.6)",   # Orange
      "rgba(26, 188, 156, 0.6)",   # Turquoise
      "rgba(149, 165, 166, 0.6)"   # Gray
    ]

    {
      labels: sorted_stages,
      datasets: [ {
        label: "Pipeline Value ($)",
        data: sorted_stages.map { |stage| stage_values[stage] },
        backgroundColor: colors[0...sorted_stages.length],
        borderColor: colors[0...sorted_stages.length].map { |color| color.gsub("0.6", "1") },
        borderWidth: 1
      } ]
    }
  end

  # 3. Monthly Revenue Trend
  def get_monthly_revenue_trend_data(since)
    won_opportunities = scoped_opportunities.where(is_closed: true, is_won: true)
                                           .where("close_date >= ?", since)
                                           .order(:close_date)

    if won_opportunities.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ {
          label: "Revenue",
          data: [ 0 ],
          borderColor: "rgba(46, 204, 113, 1)",
          backgroundColor: "rgba(46, 204, 113, 0.1)"
        } ]
      }
    end

    # Group by month
    monthly_revenue = {}
    won_opportunities.each do |opp|
      next unless opp.close_date && opp.amount

      month_key = opp.close_date.strftime("%Y-%m")
      monthly_revenue[month_key] ||= 0
      monthly_revenue[month_key] += opp.amount
    end

    # Generate labels for the last 6 months
    labels = []
    data = []
    6.times do |i|
      month = (since + i.months).strftime("%Y-%m")
      month_label = (since + i.months).strftime("%b %Y")
      labels << month_label
      data << (monthly_revenue[month] || 0)
    end

    {
      labels: labels,
      datasets: [ {
        label: "Revenue ($)",
        data: data,
        borderColor: "rgba(46, 204, 113, 1)",
        backgroundColor: "rgba(46, 204, 113, 0.1)",
        borderWidth: 2,
        fill: true,
        tension: 0.4
      } ]
    }
  end

  # 4. Revenue by Industry
  def get_revenue_by_industry_data(since)
    won_opportunities = scoped_opportunities.includes(:account)
                                           .where(is_closed: true, is_won: true)
                                           .where("close_date >= ?", since)

    if won_opportunities.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ { data: [ 1 ], backgroundColor: [ "rgba(52, 152, 219, 0.6)" ] } ]
      }
    end

    # Group by industry through account relationship
    industry_revenue = {}
    won_opportunities.each do |opp|
      next unless opp.account && opp.amount

      industry = opp.account.industry.present? ? opp.account.industry : "Unknown"
      industry_revenue[industry] ||= 0
      industry_revenue[industry] += opp.amount
    end

    colors = [
      "rgba(52, 152, 219, 0.6)",   # Blue
      "rgba(46, 204, 113, 0.6)",   # Green
      "rgba(241, 196, 15, 0.6)",   # Yellow
      "rgba(231, 76, 60, 0.6)",    # Red
      "rgba(155, 89, 182, 0.6)",   # Purple
      "rgba(230, 126, 34, 0.6)",   # Orange
      "rgba(26, 188, 156, 0.6)",   # Turquoise
      "rgba(149, 165, 166, 0.6)"   # Gray
    ]

    border_colors = colors.map { |color| color.gsub("0.6", "1") }

    {
      labels: industry_revenue.keys,
      datasets: [ {
        data: industry_revenue.values,
        backgroundColor: colors[0...industry_revenue.size],
        borderColor: border_colors[0...industry_revenue.size],
        borderWidth: 1
      } ]
    }
  end

  # 5. Case Priority Distribution
  def get_case_priority_distribution_data(since)
    cases = scoped_cases.where("salesforce_created_date >= ?", since)

    if cases.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ { data: [ 1 ], backgroundColor: [ "rgba(52, 152, 219, 0.6)" ] } ]
      }
    end

    priority_counts = cases.group(:priority).count

    colors = [
      "rgba(231, 76, 60, 0.6)",   # Red for High
      "rgba(241, 196, 15, 0.6)",  # Yellow for Medium
      "rgba(46, 204, 113, 0.6)",  # Green for Low
      "rgba(155, 89, 182, 0.6)",  # Purple for other priorities
      "rgba(52, 152, 219, 0.6)",  # Blue
      "rgba(230, 126, 34, 0.6)"   # Orange
    ]

    border_colors = colors.map { |color| color.gsub("0.6", "1") }

    {
      labels: priority_counts.keys.map { |p| p.present? ? p : "No Priority" },
      datasets: [ {
        data: priority_counts.values,
        backgroundColor: colors[0...priority_counts.size],
        borderColor: border_colors[0...priority_counts.size],
        borderWidth: 1
      } ]
    }
  end

  # 6. Account Revenue Distribution
  def get_account_revenue_distribution_data(since)
    accounts = scoped_accounts.where.not(arr: nil)
                             .where("salesforce_created_date >= ?", since)

    if accounts.empty?
      return {
        labels: [ "No Data" ],
        datasets: [ {
          label: "Accounts",
          data: [ 0 ],
          backgroundColor: "rgba(52, 152, 219, 0.6)"
        } ]
      }
    end

    # Define revenue ranges
    ranges = {
      "< $10K" => [ 0, 10000 ],
      "$10K - $50K" => [ 10000, 50000 ],
      "$50K - $100K" => [ 50000, 100000 ],
      "$100K - $500K" => [ 100000, 500000 ],
      "$500K+" => [ 500000, Float::INFINITY ]
    }

    range_counts = {}
    ranges.each { |label, _| range_counts[label] = 0 }

    accounts.each do |account|
      arr = account.arr || 0
      ranges.each do |label, (min, max)|
        if arr >= min && arr < max
          range_counts[label] += 1
          break
        end
      end
    end

    {
      labels: range_counts.keys,
      datasets: [ {
        label: "Number of Accounts",
        data: range_counts.values,
        backgroundColor: "rgba(52, 152, 219, 0.6)",
        borderColor: "rgba(52, 152, 219, 1)",
        borderWidth: 1
      } ]
    }
  end

  # Summary data for the dashboard cards
  def get_salesforce_summary_data(timeframe_start, app_type)
    {
      total_accounts: scoped_accounts.count,
      total_sales_reps: scoped_users.where(is_active: true).count,
      total_open_opportunities: scoped_opportunities.where(is_closed: false).count,
      total_revenue: scoped_opportunities.where(is_closed: true, is_won: true)
                                        .where("close_date >= ?", timeframe_start)
                                        .sum(:amount) || 0,
      total_cases: scoped_cases.where("salesforce_created_date >= ?", timeframe_start).count
    }
  end
end
