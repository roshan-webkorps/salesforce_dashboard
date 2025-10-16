// app/javascript/components/SalesforceChartComponents.jsx - Refactored
import React from 'react'
import { Bar, Doughnut, Line } from 'react-chartjs-2'
import {
  getRevenueByIndustryData,
  getTopSalesRepsData,
  getAccountAcquisitionRevenueData,
  getPipelineHealthData,
  getDealSizeDistributionData,
  getLeadSourcePerformanceData,
  getRevenueTrendData,
  getAccountSegmentDistributionData,
  getLeadStatusFunnelData,
  getCasePriorityData,
  getSalesRepRevenueByStageData,
  getTopSalesRepsClosedWonData,
  getClosedWonByTypeData,
  formatCurrency
} from './SalesforceChartDataHelpers'

// ============================================================================
// SHARED CHART OPTIONS
// ============================================================================

const createBarOptions = (customOptions = {}) => ({
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: customOptions.hideLegend ? false : true, position: 'bottom', labels: { padding: 8, usePointStyle: true, font: { size: 10 }, boxWidth: 12, boxHeight: 12 }, maxHeight: 60 },
    tooltip: customOptions.tooltip || {
      callbacks: {
        label: (context) => {
          const value = context.parsed.y || context.parsed.x
          return context.dataset.label?.includes('Revenue') || context.dataset.label?.includes('$')
            ? `${context.dataset.label}: ${formatCurrency(value)}`
            : `${context.dataset.label}: ${value.toLocaleString()}`
        }
      }
    }
  },
  scales: {
    x: { ticks: { maxRotation: 45, minRotation: customOptions.horizontal ? 0 : 0, font: { size: 9 } }, ...customOptions.xScale },
    y: { beginAtZero: true, ticks: { font: { size: 10 }, callback: customOptions.yFormat || ((value) => value.toLocaleString()) }, ...customOptions.yScale },
    ...(customOptions.y1Scale && { y1: customOptions.y1Scale })
  },
  ...(customOptions.horizontal && { indexAxis: 'y' })
})

const createLineOptions = (customOptions = {}) => ({
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { position: 'bottom', labels: { padding: 10, font: { size: 11 }, boxWidth: 12, boxHeight: 12, usePointStyle: true }, maxHeight: 60 },
    tooltip: customOptions.tooltip || {
      callbacks: {
        label: (context) => {
          const value = context.parsed.y
          if (context.dataset.label?.includes('Revenue') || context.dataset.label?.includes('$')) {
            return `${context.dataset.label}: ${formatCurrency(value)}`
          }
          return `${context.dataset.label}: ${value.toLocaleString()}`
        }
      }
    }
  },
  scales: {
    x: { ticks: { font: { size: 10 } } },
    y: { beginAtZero: true, ticks: { font: { size: 10 }, callback: customOptions.yFormat || ((value) => value.toLocaleString()) }, ...customOptions.yScale },
    ...(customOptions.y1Scale && { y1: customOptions.y1Scale })
  }
})

const pieChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { position: 'bottom', labels: { padding: 10, font: { size: 11 }, boxWidth: 12, boxHeight: 12, usePointStyle: true }, maxHeight: 60 },
    tooltip: {
      callbacks: {
        label: (context) => {
          const label = context.label || ''
          const value = context.parsed || 0
          const isCurrency = context.chart.config.data.datasets[0].label?.includes('Revenue') || value >= 1000
          return `${label}: ${isCurrency ? formatCurrency(value) : value.toLocaleString()}`
        }
      }
    }
  }
}

// ============================================================================
// HELPER: DYNAMIC TITLES
// ============================================================================

const getTitleByTimeframe = (timeframe, baseTitle, variants) => {
  const titles = {
    '24h': variants.day,
    '7d': variants.week,
    '1m': variants.month,
    '6m': variants.sixMonths,
    '1y': variants.year
  }
  return titles[timeframe] || baseTitle
}

// ============================================================================
// CHART COMPONENTS
// ============================================================================

// 1. Opportunity Creation Trend
export const OpportunityCreationTrendChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Opportunity Creation Trend - New deals over time', {
    day: 'Opportunity Creation (Last 24 Hours) - New deals by hour',
    week: 'Opportunity Creation (Last 7 Days) - New deals per day',
    month: 'Opportunity Creation (Last Month) - New deals by week',
    sixMonths: 'Opportunity Creation (Last 6 Months) - New deals by month',
    year: 'Opportunity Creation (This Year) - New deals by quarter'
  })

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-with-legend">
        <Line data={getRevenueByIndustryData(dashboardData)} options={createLineOptions()} />
      </div>
    </div>
  )
}

// 2. Sales Rep Win Rates
export const WinRateAnalysisChart = ({ dashboardData }) => {
  const horizontalWinRateOptions = {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        callbacks: {
          label: (context) => `Win Rate: ${context.parsed.x}%`
        }
      }
    },
    scales: {
      x: {
        beginAtZero: true,
        max: 100,
        ticks: {
          font: { size: 10 },
          callback: (value) => value + '%'
        }
      },
      y: {
        ticks: {
          font: { size: 10 }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>Sales Rep Win Rates - Close efficiency by rep (min 5 deals)</h3>
      <div className="chart-with-legend">
        <Bar data={getTopSalesRepsData(dashboardData)} options={horizontalWinRateOptions} />
      </div>
    </div>
  )
}

// 3. Account Acquisition vs Revenue (Dual-axis)
export const AccountAcquisitionRevenueChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Customer Acquisition vs Revenue Growth', {
    day: 'Growth Correlation (24 Hours) - New customers vs revenue by hour',
    week: 'Growth Correlation (7 Days) - New customers vs revenue by day',
    month: 'Growth Correlation (1 Month) - New customers vs revenue by week',
    sixMonths: 'Growth Correlation (6 Months) - New customers vs revenue by month',
    year: 'Growth Correlation (This Year) - New customers vs revenue by quarter'
  })

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-with-legend">
        <Line 
          data={getAccountAcquisitionRevenueData(dashboardData)} 
          options={createLineOptions({
            yScale: { title: { display: true, text: 'New Accounts', font: { size: 11 } } },
            y1Scale: {
              type: 'linear',
              display: true,
              position: 'right',
              beginAtZero: true,
              title: { display: true, text: 'Revenue ($)', font: { size: 11 } },
              grid: { drawOnChartArea: false },
              ticks: { font: { size: 10 }, callback: (value) => formatCurrency(value) }
            }
          })}
        />
      </div>
    </div>
  )
}

// 4. Pipeline Value by Stage
export const PipelineHealthChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Pipeline Value by Stage - Dollar amount in each stage</h3>
    <div className="chart-with-legend">
      <Bar 
        data={getPipelineHealthData(dashboardData)} 
        options={createBarOptions({ 
          yFormat: formatCurrency,
          tooltip: { callbacks: { label: (ctx) => `Pipeline Value: ${formatCurrency(ctx.parsed.y)}` } }
        })} 
      />
    </div>
  </div>
)

// 5. Deal Size Distribution (Donut)
export const DealSizeDistributionChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Deal Size Distribution - Won deals grouped by revenue range</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getDealSizeDistributionData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 6. Lead Conversion Rate by Source
export const LeadSourcePerformanceChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Lead Conversion by Source - Quality of leads from each source</h3>
    <div className="chart-with-legend">
      <Bar 
        data={getLeadSourcePerformanceData(dashboardData)} 
        options={createBarOptions({ 
          yFormat: (value) => value + '%',
          yScale: { max: 100 },
          tooltip: { callbacks: { label: (ctx) => `Conversion Rate: ${ctx.parsed.y}%` } }
        })} 
      />
    </div>
  </div>
)

// 7. Revenue Trend
export const RevenueTrendChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Revenue Growth Trend', {
    day: 'Revenue Trend (24 Hours) - Money earned by hour',
    week: 'Revenue Trend (7 Days) - Money earned per day',
    month: 'Revenue Trend (1 Month) - Money earned by week',
    sixMonths: 'Revenue Trend (6 Months) - Money earned by month',
    year: 'Revenue Trend (This Year) - Money earned by quarter'
  })

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-with-legend">
        <Line data={getRevenueTrendData(dashboardData)} options={createLineOptions({ yFormat: formatCurrency })} />
      </div>
    </div>
  )
}

// 8. Account Segment Distribution (Donut)
export const AccountSegmentDistributionChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Customer Segments - Breakdown of customer types</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getAccountSegmentDistributionData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 9. Lead Conversion Funnel (Horizontal Bar)
export const LeadStatusFunnelChart = ({ dashboardData }) => {
  const horizontalFunnelOptions = {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        callbacks: {
          label: (context) => `Leads: ${context.parsed.x.toLocaleString()}`
        }
      }
    },
    scales: {
      x: {
        beginAtZero: true,
        ticks: {
          font: { size: 10 },
          callback: (value) => value.toLocaleString()
        }
      },
      y: {
        ticks: {
          font: { size: 10 }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>Lead Conversion Funnel - Prospects at each stage</h3>
      <div className="chart-with-legend">
        <Bar data={getLeadStatusFunnelData(dashboardData)} options={horizontalFunnelOptions} />
      </div>
    </div>
  )
}

// 10. Case Priority Distribution (Donut)
export const CasePriorityChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Support Workload - Open cases by priority level</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getCasePriorityData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 11. Sales Rep Revenue by Stage (Grouped Bar)
export const SalesRepRevenueByStageChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Sales Rep Performance - Renewal revenue by rep and stage', {
    day: 'Sales Rep Performance (Today) - Renewal revenue by rep and stage',
    week: 'Sales Rep Performance (7 Days) - Renewal revenue by rep and stage',
    month: 'Sales Rep Performance (This Month) - Renewal revenue by rep and stage',
    sixMonths: 'Sales Rep Performance (6 Months) - Renewal revenue by rep and stage',
    year: 'Sales Rep Performance (This Year) - Renewal revenue by rep and stage'
  })

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-with-legend">
        <Bar 
          data={getSalesRepRevenueByStageData(dashboardData)} 
          options={createBarOptions({ 
            yFormat: formatCurrency,
            tooltip: { callbacks: { label: (ctx) => `${ctx.dataset.label}: ${formatCurrency(ctx.parsed.y)}` } }
          })} 
        />
      </div>
    </div>
  )
}

// 12. Top Performers (Vertical Bar)
export const TopSalesRepsClosedWonChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Top Performers - Actual revenue closed by rep', {
    day: 'Top Performers (Today) - Actual revenue closed by rep',
    week: 'Top Performers (7 Days) - Actual revenue closed by rep',
    month: 'Top Performers (This Month) - Actual revenue closed by rep',
    sixMonths: 'Top Performers (6 Months) - Actual revenue closed by rep',
    year: 'Top Performers (This Year) - Actual revenue closed by rep'
  })

  return (
    <div className="chart-container">
      <h3>{title}</h3>
      <div className="chart-with-legend">
        <Bar 
          data={getTopSalesRepsClosedWonData(dashboardData)} 
          options={createBarOptions({ 
            hideLegend: true,
            yFormat: formatCurrency,
            tooltip: { callbacks: { label: (ctx) => `Revenue: ${formatCurrency(ctx.parsed.y)}` } }
          })} 
        />
      </div>
    </div>
  )
}

// 13. Revenue Mix (Donut)
export const ClosedWonByTypeChart = ({ dashboardData }) => {
  const title = getTitleByTimeframe(dashboardData?.timeframe, 'Revenue Mix - Deal types generating revenue', {
    day: 'Revenue Mix (Today) - Deal types generating revenue',
    week: 'Revenue Mix (7 Days) - Deal types generating revenue',
    month: 'Revenue Mix (This Month) - Deal types generating revenue',
    sixMonths: 'Revenue Mix (6 Months) - Deal types generating revenue',
    year: 'Revenue Mix (This Year) - Deal types generating revenue'
  })

  return (
    <div className="chart-container pie-chart-container">
      <h3>{title}</h3>
      <div className="pie-chart-wrapper">
        <Doughnut data={getClosedWonByTypeData(dashboardData)} options={pieChartOptions} />
      </div>
    </div>
  )
}
