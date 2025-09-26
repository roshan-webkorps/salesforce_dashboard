// app/javascript/components/SalesforceChartComponents.jsx - Individual chart components for Salesforce dashboard
import React from 'react'
import { Bar, Doughnut, Line } from 'react-chartjs-2'
import {
  getRevenueByRepData,
  getSalesPipelineData,
  getMonthlyRevenueTrendData,
  getRevenueByIndustryData,
  getCasePriorityData,
  getAccountRevenueDistributionData,
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
        font: {
          size: 10
        },
        boxWidth: 12,
        boxHeight: 12,
      },
      maxHeight: 60,
    },
    tooltip: {
      callbacks: {
        label: function(context) {
          return `${context.dataset.label}: ${formatCurrency(context.parsed.y)}`
        }
      }
    }
  },
  scales: {
    x: {
      ticks: {
        maxRotation: 45,
        minRotation: 0,
        font: {
          size: 10
        }
      }
    },
    y: {
      ticks: {
        font: {
          size: 10
        },
        callback: function(value) {
          return formatCurrency(value)
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
        font: {
          size: 11
        },
        boxWidth: 12,
        boxHeight: 12,
        usePointStyle: true
      },
      maxHeight: 60,
    },
    tooltip: {
      callbacks: {
        label: function(context) {
          return `${context.dataset.label}: ${formatCurrency(context.parsed.y)}`
        }
      }
    }
  },
  scales: {
    x: {
      ticks: {
        font: {
          size: 10
        }
      }
    },
    y: {
      ticks: {
        font: {
          size: 10
        },
        callback: function(value) {
          return formatCurrency(value)
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
        font: {
          size: 11
        },
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
          
          // For revenue charts, format as currency; for count charts, format as numbers
          const formattedValue = datasetLabel.includes('Revenue') || datasetLabel.includes('$')
                                 ? formatCurrency(value) 
                                 : value.toLocaleString()
          return `${label}: ${formattedValue}`
        }
      }
    }
  }
}

// 1. Revenue by Sales Rep Chart
export const RevenueByRepChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Revenue by Sales Rep</h3>
    <div className="chart-with-legend">
      <Bar data={getRevenueByRepData(dashboardData)} options={barChartOptions} />
    </div>
  </div>
)

// 2. Sales Pipeline by Stage Chart
export const SalesPipelineChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Sales Pipeline by Stage</h3>
    <div className="chart-with-legend">
      <Bar data={getSalesPipelineData(dashboardData)} options={barChartOptions} />
    </div>
  </div>
)

// 3. Monthly Revenue Trend Chart
export const MonthlyRevenueTrendChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Monthly Revenue Trend</h3>
    <div className="chart-with-legend">
      <Line data={getMonthlyRevenueTrendData(dashboardData)} options={lineChartOptions} />
    </div>
  </div>
)

// 4. Revenue by Industry Chart
export const RevenueByIndustryChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Revenue by Industry</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getRevenueByIndustryData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 5. Case Priority Distribution Chart
export const CasePriorityChart = ({ dashboardData }) => (
  <div className="chart-container pie-chart-container">
    <h3>Case Priority Distribution</h3>
    <div className="pie-chart-wrapper">
      <Doughnut data={getCasePriorityData(dashboardData)} options={pieChartOptions} />
    </div>
  </div>
)

// 6. Account Revenue Distribution Chart
export const AccountRevenueDistributionChart = ({ dashboardData }) => (
  <div className="chart-container">
    <h3>Account Revenue Distribution</h3>
    <div className="chart-with-legend">
      <Bar 
        data={getAccountRevenueDistributionData(dashboardData)} 
        options={{
          ...barChartOptions,
          plugins: {
            ...barChartOptions.plugins,
            tooltip: {
              callbacks: {
                label: function(context) {
                  return `${context.dataset.label}: ${context.parsed.y} accounts`
                }
              }
            }
          },
          scales: {
            ...barChartOptions.scales,
            y: {
              ticks: {
                font: {
                  size: 10
                },
                callback: function(value) {
                  return value.toLocaleString()
                }
              }
            }
          }
        }} 
      />
    </div>
  </div>
)
