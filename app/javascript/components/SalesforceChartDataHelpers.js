// app/javascript/components/SalesforceChartDataHelpers.js - Optimized chart data helpers

// ============================================================================
// NEW OPTIMIZED METRIC DATA HELPERS
// ============================================================================

// 1. Revenue by Industry (Multi-model: Account + Opportunity)
export const getRevenueByIndustryData = (dashboardData) => {
  if (!dashboardData?.charts_data?.revenue_by_industry) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        data: [1], 
        backgroundColor: ['rgba(52, 152, 219, 0.6)'] 
      }]
    }
  }
  
  return dashboardData.charts_data.revenue_by_industry
}

// 2. Top Sales Reps (Multi-model: User + Opportunity)
export const getTopSalesRepsData = (dashboardData) => {
  if (!dashboardData?.charts_data?.top_sales_reps) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Revenue ($)', 
        data: [0], 
        backgroundColor: 'rgba(46, 204, 113, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.top_sales_reps
}

// 3. Account Acquisition vs Revenue (Multi-model: Account + Opportunity)
export const getAccountAcquisitionRevenueData = (dashboardData) => {
  if (!dashboardData?.charts_data?.account_acquisition_revenue) {
    return {
      labels: ['Loading...'],
      datasets: [{
        label: 'New Accounts',
        data: [0],
        borderColor: 'rgba(52, 152, 219, 1)',
        backgroundColor: 'rgba(52, 152, 219, 0.1)',
        yAxisID: 'y'
      }, {
        label: 'Revenue ($)',
        data: [0],
        borderColor: 'rgba(46, 204, 113, 1)',
        backgroundColor: 'rgba(46, 204, 113, 0.1)',
        yAxisID: 'y1'
      }]
    }
  }
  
  return dashboardData.charts_data.account_acquisition_revenue
}

// 4. Pipeline Health by Stage (Single model: Opportunity)
export const getPipelineHealthData = (dashboardData) => {
  if (!dashboardData?.charts_data?.pipeline_health) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Opportunities', 
        data: [0], 
        backgroundColor: 'rgba(52, 152, 219, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.pipeline_health
}

// 5. Deal Size Distribution (Single model: Opportunity)
export const getDealSizeDistributionData = (dashboardData) => {
  if (!dashboardData?.charts_data?.deal_size_distribution) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Number of Deals', 
        data: [0], 
        backgroundColor: 'rgba(155, 89, 182, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.deal_size_distribution
}

// 6. Lead Source Performance (Single model: Lead)
export const getLeadSourcePerformanceData = (dashboardData) => {
  if (!dashboardData?.charts_data?.lead_source_performance) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        data: [1], 
        backgroundColor: ['rgba(155, 89, 182, 0.6)'] 
      }]
    }
  }
  
  return dashboardData.charts_data.lead_source_performance
}

// 7. Revenue Trend (Single model: Opportunity)
export const getRevenueTrendData = (dashboardData) => {
  if (!dashboardData?.charts_data?.revenue_trend) {
    return {
      labels: ['Loading...'],
      datasets: [{
        label: 'Revenue ($)',
        data: [0],
        borderColor: 'rgba(46, 204, 113, 1)',
        backgroundColor: 'rgba(46, 204, 113, 0.1)',
        borderWidth: 2,
        fill: true,
        tension: 0.4
      }]
    }
  }
  
  return dashboardData.charts_data.revenue_trend
}

// 8. Account Segment Distribution (Single model: Account)
export const getAccountSegmentDistributionData = (dashboardData) => {
  if (!dashboardData?.charts_data?.account_segment_distribution) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        data: [1], 
        backgroundColor: ['rgba(230, 126, 34, 0.6)'] 
      }]
    }
  }
  
  return dashboardData.charts_data.account_segment_distribution
}

// 9. Lead Status Funnel (Single model: Lead)
export const getLeadStatusFunnelData = (dashboardData) => {
  if (!dashboardData?.charts_data?.lead_status_funnel) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Leads', 
        data: [0], 
        backgroundColor: 'rgba(26, 188, 156, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.lead_status_funnel
}

// 10. Case Priority Distribution (Single model: Case)
export const getCasePriorityData = (dashboardData) => {
  if (!dashboardData?.charts_data?.case_priority_distribution) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        data: [1], 
        backgroundColor: ['rgba(231, 76, 60, 0.6)'] 
      }]
    }
  }
  
  return dashboardData.charts_data.case_priority_distribution
}

// 11. Sales Rep Revenue by Stage (Multi-model: User + Opportunity)
export const getSalesRepRevenueByStageData = (dashboardData) => {
  if (!dashboardData?.charts_data?.sales_rep_revenue_by_stage) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Revenue ($)', 
        data: [0], 
        backgroundColor: 'rgba(52, 152, 219, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.sales_rep_revenue_by_stage
}

// 12. Top Sales Reps by Closed Won Revenue
export const getTopSalesRepsClosedWonData = (dashboardData) => {
  if (!dashboardData?.charts_data?.top_sales_reps_closed_won) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        label: 'Revenue ($)', 
        data: [0], 
        backgroundColor: 'rgba(46, 204, 113, 0.6)' 
      }]
    }
  }
  
  return dashboardData.charts_data.top_sales_reps_closed_won
}

// 13. Closed Won Revenue by Opportunity Type
export const getClosedWonByTypeData = (dashboardData) => {
  if (!dashboardData?.charts_data?.closed_won_by_type) {
    return {
      labels: ['Loading...'],
      datasets: [{ 
        data: [1], 
        backgroundColor: ['rgba(52, 152, 219, 0.6)'] 
      }]
    }
  }
  
  return dashboardData.charts_data.closed_won_by_type
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Format currency values for display
export const formatCurrency = (amount) => {
  if (!amount) return '$0'
  
  // Convert to millions/thousands for readability
  if (amount >= 1000000) {
    return `$${(amount / 1000000).toFixed(1)}M`
  } else if (amount >= 1000) {
    return `$${(amount / 1000).toFixed(1)}K`
  } else {
    return `$${amount.toLocaleString()}`
  }
}

// Format large numbers for display
export const formatNumber = (num) => {
  if (!num) return '0'
  return num.toLocaleString()
}

// Color palettes for consistent theming
export const salesColors = {
  primary: 'rgba(46, 204, 113, 0.6)',      // Green for revenue/success
  secondary: 'rgba(52, 152, 219, 0.6)',    // Blue for pipeline/neutral
  warning: 'rgba(241, 196, 15, 0.6)',      // Yellow for warnings
  danger: 'rgba(231, 76, 60, 0.6)',        // Red for urgent/lost
  info: 'rgba(26, 188, 156, 0.6)',         // Teal for information
  purple: 'rgba(155, 89, 182, 0.6)',       // Purple
  orange: 'rgba(230, 126, 34, 0.6)',       // Orange
  gray: 'rgba(149, 165, 166, 0.6)'         // Gray
}

export const salesBorderColors = {
  primary: 'rgba(46, 204, 113, 1)',
  secondary: 'rgba(52, 152, 219, 1)',
  warning: 'rgba(241, 196, 15, 1)',
  danger: 'rgba(231, 76, 60, 1)',
  info: 'rgba(26, 188, 156, 1)',
  purple: 'rgba(155, 89, 182, 1)',
  orange: 'rgba(230, 126, 34, 1)',
  gray: 'rgba(149, 165, 166, 1)'
}
