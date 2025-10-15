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
  getSalesRepRevenueByStageData,
  getTopSalesRepsClosedWonData,
  getClosedWonByTypeData,
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
          
          // Check if this is a revenue/currency chart by looking at dataset label or checking if values are large
          const isCurrency = datasetLabel.includes('Revenue') || 
                            datasetLabel.includes('$') || 
                            value >= 1000
          
          const formattedValue = isCurrency ? formatCurrency(value) : value.toLocaleString()
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

// 2. Sales Rep Win Rates (Horizontal Bar) - REPLACE EXISTING WinRateAnalysisChart
export const WinRateAnalysisChart = ({ dashboardData }) => {
  // Horizontal bar chart options with green color
  const horizontalBarOptions = {
    indexAxis: 'y', // Horizontal bars
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            return `Win Rate: ${context.parsed.x}%`
          }
        }
      }
    },
    scales: {
      x: {
        beginAtZero: true,
        max: 100,
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return value + '%'
          }
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
        <Bar data={getTopSalesRepsData(dashboardData)} options={horizontalBarOptions} />
      </div>
    </div>
  )
}

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

// 4. Pipeline Value by Stage (Bar Chart) - REPLACE EXISTING PipelineHealthChart
export const PipelineHealthChart = ({ dashboardData }) => {
  const pipelineBarOptions = {
    ...barChartOptions,
    plugins: {
      ...barChartOptions.plugins,
      tooltip: {
        callbacks: {
          label: function(context) {
            return `Pipeline Value: ${formatCurrency(context.parsed.y)}`
          }
        }
      }
    },
    scales: {
      x: {
        ticks: {
          maxRotation: 45,
          minRotation: 45,
          font: { size: 10 }
        }
      },
      y: {
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return formatCurrency(value)
          }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>Pipeline Value by Stage - Dollar amount in each stage</h3>
      <div className="chart-with-legend">
        <Bar data={getPipelineHealthData(dashboardData)} options={pipelineBarOptions} />
      </div>
    </div>
  )
}

// 5. Deal Size Distribution (Donut Chart) - REPLACE EXISTING
export const DealSizeDistributionChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Deal Size Distribution - Won deals grouped by revenue range</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getDealSizeDistributionData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 6. Lead Conversion Rate by Source (Bar Chart) - REPLACE EXISTING LeadSourcePerformanceChart
export const LeadSourcePerformanceChart = ({ dashboardData }) => {
  const conversionBarOptions = {
    ...barChartOptions,
    plugins: {
      ...barChartOptions.plugins,
      tooltip: {
        callbacks: {
          label: function(context) {
            return `Conversion Rate: ${context.parsed.y}%`
          }
        }
      }
    },
    scales: {
      x: {
        ticks: {
          maxRotation: 45,
          minRotation: 45,
          font: { size: 10 }
        }
      },
      y: {
        beginAtZero: true,
        max: 100,
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return value + '%'
          }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>Lead Conversion by Source - Quality of leads from each source</h3>
      <div className="chart-with-legend">
        <Bar data={getLeadSourcePerformanceData(dashboardData)} options={conversionBarOptions} />
      </div>
    </div>
  )
}

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

// 9. Lead Status Funnel (Horizontal Bar Chart) - REPLACE EXISTING
export const LeadStatusFunnelChart = ({ dashboardData }) => {
  // Horizontal bar chart options for funnel
  const horizontalFunnelOptions = {
    indexAxis: 'y', // Makes bars horizontal
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            return `Leads: ${context.parsed.x.toLocaleString()}`
          }
        }
      }
    },
    scales: {
      x: {
        beginAtZero: true,
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return value.toLocaleString()
          }
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

// 10. Case Priority Distribution (Single model: Case)
export const CasePriorityChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Support Workload - Open cases by priority level</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getCasePriorityData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 11. Sales Rep Revenue by Stage (Multi-model: User + Opportunity)
export const SalesRepRevenueByStageChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Sales Rep Performance (Today) - Renewal revenue by rep and stage'
      case '7d': return 'Sales Rep Performance (7 Days) - Renewal revenue by rep and stage'
      case '1m': return 'Sales Rep Performance (This Month) - Renewal revenue by rep and stage'
      case '6m': return 'Sales Rep Performance (6 Months) - Renewal revenue by rep and stage'
      case '1y': return 'Sales Rep Performance (This Year) - Renewal revenue by rep and stage'
      default: return 'Sales Rep Performance - Renewal revenue by rep and stage'
    }
  }

  // Custom options for GROUPED bar chart with currency formatting
  const groupedBarOptions = {
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
            return `${context.dataset.label}: ${formatCurrency(value)}`
          }
        }
      }
    },
    scales: {
      x: {
        ticks: {
          maxRotation: 45,
          minRotation: 45,
          font: { size: 9 }
        }
      },
      y: {
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return formatCurrency(value)
          }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="chart-with-legend">
        <Bar data={getSalesRepRevenueByStageData(dashboardData)} options={groupedBarOptions} />
      </div>
    </div>
  )
}

// 12. Top Sales Reps by Closed Won Revenue (Horizontal Bar)
export const TopSalesRepsClosedWonChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Top Performers (Today) - Actual revenue closed by rep'
      case '7d': return 'Top Performers (7 Days) - Actual revenue closed by rep'
      case '1m': return 'Top Performers (This Month) - Actual revenue closed by rep'
      case '6m': return 'Top Performers (6 Months) - Actual revenue closed by rep'
      case '1y': return 'Top Performers (This Year) - Actual revenue closed by rep'
      default: return 'Top Performers - Actual revenue closed by rep'
    }
  }

  // Vertical bar chart options with blue color
  const verticalBarOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            const value = context.parsed.y
            return `Revenue: ${formatCurrency(value)}`
          }
        }
      }
    },
    scales: {
      x: {
        ticks: {
          maxRotation: 45,
          minRotation: 45,
          font: { size: 9 }
        }
      },
      y: {
        beginAtZero: true,
        ticks: {
          font: { size: 10 },
          callback: function(value) {
            return formatCurrency(value)
          }
        }
      }
    }
  }

  return (
    <div className="chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="chart-with-legend">
        <Bar data={getTopSalesRepsClosedWonData(dashboardData)} options={verticalBarOptions} />
      </div>
    </div>
  )
}

// 13. Closed Won Revenue by Opportunity Type (Donut)
export const ClosedWonByTypeChart = ({ dashboardData }) => {
  const getChartTitle = () => {
    const timeframe = dashboardData?.timeframe || '24h'
    switch(timeframe) {
      case '24h': return 'Revenue Mix (Today) - Deal types generating revenue'
      case '7d': return 'Revenue Mix (7 Days) - Deal types generating revenue'
      case '1m': return 'Revenue Mix (This Month) - Deal types generating revenue'
      case '6m': return 'Revenue Mix (6 Months) - Deal types generating revenue'
      case '1y': return 'Revenue Mix (This Year) - Deal types generating revenue'
      default: return 'Revenue Mix - Deal types generating revenue'
    }
  }

  return (
    <div className="chart-container pie-chart-container">
      <h3>{getChartTitle()}</h3>
      <div className="pie-chart-wrapper">
        <Doughnut data={getClosedWonByTypeData(dashboardData)} options={pieChartOptions} />
      </div>
    </div>
  )
}
