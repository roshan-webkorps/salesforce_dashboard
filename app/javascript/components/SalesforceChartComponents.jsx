// app/javascript/components/SalesforceChartComponents.jsx - Optimized chart components
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
  formatCurrency
} from './SalesforceChartDataHelpers'

const barChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        padding: 8,
        usePointStyle: true,
        font: { size: 10 },
        boxWidth: 12,
        boxHeight: 12,
      },
      maxHeight: 60,
    },
    tooltip: {
      callbacks: {
        label: function(context) {
          const value = context.parsed.y
          return context.dataset.label.includes('Revenue') || context.dataset.label.includes('$')
            ? `${context.dataset.label}: ${formatCurrency(value)}`
            : `${context.dataset.label}: ${value.toLocaleString()}`
        }
      }
    }
  },
  scales: {
    x: {
      ticks: {
        maxRotation: 45,
        minRotation: 0,
        font: { size: 10 }
      }
    },
    y: {
      ticks: {
        font: { size: 10 },
        callback: function(value) {
          return this.chart.config.data.datasets[0].label?.includes('Revenue') || 
                 this.chart.config.data.datasets[0].label?.includes('$')
            ? formatCurrency(value)
            : value.toLocaleString()
        }
      }
    }
  }
}

const lineChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        padding: 10,
        font: { size: 11 },
        boxWidth: 12,
        boxHeight: 12,
        usePointStyle: true
      },
      maxHeight: 60,
    },
    tooltip: {
      callbacks: {
        label: function(context) {
          const value = context.parsed.y
          return context.dataset.label.includes('Revenue') || context.dataset.label.includes('$')
            ? `${context.dataset.label}: ${formatCurrency(value)}`
            : `${context.dataset.label}: ${value.toLocaleString()}`
        }
      }
    }
  },
  scales: {
    x: {
      ticks: { font: { size: 10 } }
    },
    y: {
      type: 'linear',
      display: true,
      position: 'left',
      ticks: {
        font: { size: 10 },
        callback: function(value) {
          return formatCurrency(value)
        }
      }
    },
    y1: {
      type: 'linear',
      display: true,
      position: 'right',
      grid: {
        drawOnChartArea: false,
      },
      ticks: {
        font: { size: 10 },
        callback: function(value) {
          return value.toLocaleString()
        }
      }
    }
  }
}

const pieChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        padding: 10,
        font: { size: 11 },
        boxWidth: 12,
        boxHeight: 12,
        usePointStyle: true
      },
      maxHeight: 60,
    },
    tooltip: {
      callbacks: {
        label: function(context) {
          const label = context.label || ''
          const value = context.parsed || 0
          const datasetLabel = context.chart.config.data.datasets[0].label || ''
          
          const formattedValue = datasetLabel.includes('Revenue') || datasetLabel.includes('$')
                                 ? formatCurrency(value) 
                                 : value.toLocaleString()
          return `${label}: ${formattedValue}`
        }
      }
    }
  }
}

// 1. Opportunity Creation Trend (Single model: Opportunity) - Dynamic timeframes
export const OpportunityCreationTrendChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Opportunity Creation (Last 24 Hours) - New deals by hour'
      case '7d': return 'Opportunity Creation (Last 7 Days) - New deals per day'
      case '1m': return 'Opportunity Creation (Last Month) - New deals by week'
      case '6m': return 'Opportunity Creation (Last 6 Months) - New deals by month'
      case '1y': return 'Opportunity Creation (This Year) - New deals by quarter'
      default: return 'Opportunity Creation Trend - New deals over time'
    }
  }

  return (
    <div className="chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="chart-with-legend">
        <Line data={getRevenueByIndustryData(dashboardData)} options={lineChartOptions} />
      </div>
    </div>
  )
}

// 2. Win Rate Analysis (Single model: Opportunity)
export const WinRateAnalysisChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Sales Performance - Win vs Loss rate for closed deals</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getTopSalesRepsData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 3. Account Acquisition vs Revenue (Multi-model: Account + Opportunity)
export const AccountAcquisitionRevenueChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Growth Correlation (24 Hours) - New customers vs revenue by hour'
      case '7d': return 'Growth Correlation (7 Days) - New customers vs revenue by day'
      case '1m': return 'Growth Correlation (1 Month) - New customers vs revenue by week'
      case '6m': return 'Growth Correlation (6 Months) - New customers vs revenue by month'
      case '1y': return 'Growth Correlation (This Year) - New customers vs revenue by quarter'
      default: return 'Customer Acquisition vs Revenue Growth'
    }
  }

  return (
    <div className="chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="chart-with-legend">
        <Line data={getAccountAcquisitionRevenueData(dashboardData)} options={lineChartOptions} />
      </div>
    </div>
  )
}

// 4. Pipeline Health by Stage (Single model: Opportunity)
export const PipelineHealthChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Sales Pipeline Health - Open opportunities by stage</h3>
    <div className="chart-with-legend">
      <Bar data={getPipelineHealthData(dashboardData)} options={barChartOptions} />
    </div>
  </div>
)

// 5. Deal Size Distribution (Single model: Opportunity)
export const DealSizeDistributionChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Deal Size Analysis - Won deals grouped by revenue range</h3>
    <div className="chart-with-legend">
      <Bar data={getDealSizeDistributionData(dashboardData)} options={barChartOptions} />
    </div>
  </div>
)

// 6. Lead Source Performance (Single model: Lead)
export const LeadSourcePerformanceChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Lead Generation Sources - Where prospects come from</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getLeadSourcePerformanceData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 7. Revenue Trend (Single model: Opportunity)
export const RevenueTrendChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Revenue Trend (24 Hours) - Money earned by hour'
      case '7d': return 'Revenue Trend (7 Days) - Money earned per day'
      case '1m': return 'Revenue Trend (1 Month) - Money earned by week'
      case '6m': return 'Revenue Trend (6 Months) - Money earned by month'
      case '1y': return 'Revenue Trend (This Year) - Money earned by quarter'
      default: return 'Revenue Growth Trend'
    }
  }

  return (
    <div className="chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="chart-with-legend">
        <Line data={getRevenueTrendData(dashboardData)} options={lineChartOptions} />
      </div>
    </div>
  )
}

// 8. Account Segment Distribution (Single model: Account)
export const AccountSegmentDistributionChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Customer Segments - Breakdown of customer types</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getAccountSegmentDistributionData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 9. Lead Status Funnel (Single model: Lead)
export const LeadStatusFunnelChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Lead Conversion Funnel - Prospects at each stage</h3>
    <div className="chart-with-legend">
      <Bar data={getLeadStatusFunnelData(dashboardData)} options={barChartOptions} />
    </div>
  </div>
)

// 10. Case Priority Distribution (Single model: Case)
export const CasePriorityChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Support Workload - Open cases by priority level</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getCasePriorityData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)
