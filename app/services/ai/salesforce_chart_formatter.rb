# app/services/ai/salesforce_chart_formatter.rb
module Ai
  class SalesforceChartFormatter
    def self.format_results(results, ai_response, user_query)
      return { error: "No results found" } if results.empty?

      chart_type = ai_response["chart_type"] || "table"
      description = ai_response["description"] || "Query Results"

      formatted_data = case chart_type
      when "bar"
        format_for_bar_chart(results)
      when "pie"
        format_for_pie_chart(results)
      else
        format_for_table(results)
      end

      {
        success: true,
        user_query: user_query,
        description: description,
        chart_type: chart_type,
        data: formatted_data,
        raw_results: results
      }
    end

    private

    def self.format_for_bar_chart(results)
      columns = results.first.keys

      value_column = detect_value_column(columns, results)
      label_column = detect_label_column(columns)

      return format_for_table(results) unless value_column && label_column

      labels = results.map { |row| format_label(row[label_column]) }
      values = results.map { |row| format_numeric_value(row[value_column]) }

      {
        labels: labels,
        datasets: [ {
          label: value_column.humanize,
          data: values,
          backgroundColor: generate_bar_colors(values.length),
          borderColor: generate_bar_colors(values.length, border: true),
          borderWidth: 1
        } ]
      }
    end

    def self.format_for_pie_chart(results)
      columns = results.first.keys
      return format_for_table(results) unless columns.length >= 2

      labels = results.map { |row| format_label(row[columns[0]]) }
      values = results.map { |row| format_numeric_value(row[columns[1]]) }

      {
        labels: labels,
        datasets: [ {
          data: values,
          backgroundColor: generate_pie_colors(values.length),
          borderColor: generate_pie_colors(values.length, border: true),
          borderWidth: 1
        } ]
      }
    end

    def self.format_for_table(results)
      headers = results.first&.keys || []
      formatted_headers = headers.map { |h| h.humanize.titleize }

      formatted_rows = results.map do |row|
        row.values.map { |value| format_table_value(value) }
      end

      {
        headers: formatted_headers,
        rows: formatted_rows,
        raw_headers: headers
      }
    end

    # Helper methods

    def self.detect_value_column(columns, results)
      priority_columns = [
        "total", "total_revenue", "total_amount", "count", "opportunity_count",
        "deal_count", "revenue", "amount", "opportunities", "leads", "cases",
        "accounts", "conversion_rate", "win_rate", "pipeline_value"
      ]

      priority_match = priority_columns.find { |col| columns.include?(col) }
      return priority_match if priority_match

      numeric_columns = columns.select do |col|
        sample_value = results.first[col]
        sample_value.is_a?(Numeric) ||
        (sample_value.is_a?(String) && sample_value.match?(/^\d+\.?\d*$/))
      end

      numeric_columns.second || numeric_columns.first
    end

    def self.detect_label_column(columns)
      priority_labels = [
        "name", "sales_rep_name", "owner_name", "account_name", "opportunity_name",
        "stage_name", "status", "lead_source", "industry", "period", "month"
      ]

      priority_match = priority_labels.find { |col| columns.include?(col) }
      return priority_match if priority_match

      columns.first
    end

    def self.format_label(value)
      return value.to_s if value.nil?

      label = value.to_s
      label = label.gsub(/[-_]/, " ").titleize if label.include?("-") || label.include?("_")
      label
    end

    def self.format_numeric_value(value)
      case value
      when Numeric
        value.to_f
      when String
        value.match?(/^\d+\.?\d*$/) ? value.to_f : 0
      else
        0
      end
    end

    def self.format_table_value(value)
      case value
      when Time, DateTime
        value.strftime("%b %d, %Y")
      when Date
        value.strftime("%b %d, %Y")
      when Float
        if value > 1000
          format_currency_display(value)
        else
          value.round(2)
        end
      when Numeric
        if value > 1000
          number_with_commas(value)
        else
          value
        end
      when nil
        "-"
      else
        value.to_s
      end
    end

    def self.format_currency_display(value)
      if value >= 1_000_000
        "$#{(value / 1_000_000).round(1)}M"
      elsif value >= 1_000
        "$#{(value / 1_000).round(1)}K"
      else
        "$#{value.round(2)}"
      end
    end

    def self.number_with_commas(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def self.generate_bar_colors(count, border: false)
      base_colors = [
        "rgba(52, 152, 219, #{border ? '1' : '0.6'})",   # Blue
        "rgba(46, 204, 113, #{border ? '1' : '0.6'})",   # Green
        "rgba(241, 196, 15, #{border ? '1' : '0.6'})",   # Yellow
        "rgba(231, 76, 60, #{border ? '1' : '0.6'})",    # Red
        "rgba(155, 89, 182, #{border ? '1' : '0.6'})",   # Purple
        "rgba(230, 126, 34, #{border ? '1' : '0.6'})"   # Orange
      ]

      base_colors.cycle.take(count)
    end

    def self.generate_pie_colors(count, border: false)
      base_colors = [
        "rgba(52, 152, 219, #{border ? '1' : '0.7'})",   # Blue
        "rgba(46, 204, 113, #{border ? '1' : '0.7'})",   # Green
        "rgba(241, 196, 15, #{border ? '1' : '0.7'})",   # Yellow
        "rgba(231, 76, 60, #{border ? '1' : '0.7'})",    # Red
        "rgba(155, 89, 182, #{border ? '1' : '0.7'})",   # Purple
        "rgba(230, 126, 34, #{border ? '1' : '0.7'})",   # Orange
        "rgba(26, 188, 156, #{border ? '1' : '0.7'})",   # Turquoise
        "rgba(243, 156, 18, #{border ? '1' : '0.7'})"   # Dark Orange
      ]

      base_colors.cycle.take(count)
    end
  end
end
