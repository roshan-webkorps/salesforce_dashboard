// app/javascript/components/SalesforceChartDataHelpers.js - Handles all chart data transformations for Salesforce

// 1. Revenue by Sales Rep
export const getRevenueByRepData = (dashboardData) => {
    if (!dashboardData?.charts_data?.revenue_by_sales_rep) {
        return {
        labels: ['Loading...'],
        datasets: [{ 
            label: 'Revenue ($)', 
            data: [0], 
            backgroundColor: 'rgba(46, 204, 113, 0.6)' 
        }]
        }
    }

    return dashboardData.charts_data.revenue_by_sales_rep
}

    // 2. Sales Pipeline by Stage
export const getSalesPipelineData = (dashboardData) => {
    if (!dashboardData?.charts_data?.sales_pipeline_by_stage) {
        return {
        labels: ['Loading...'],
        datasets: [{ 
            label: 'Pipeline Value ($)', 
            data: [0], 
            backgroundColor: 'rgba(52, 152, 219, 0.6)' 
        }]
        }
    }

    return dashboardData.charts_data.sales_pipeline_by_stage
}

// 3. Monthly Revenue Trend
export const getMonthlyRevenueTrendData = (dashboardData) => {
    if (!dashboardData?.charts_data?.monthly_revenue_trend) {
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

    return dashboardData.charts_data.monthly_revenue_trend
}

// 4. Revenue by Industry
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

// 5. Case Priority Distribution
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

// 6. Account Revenue Distribution
export const getAccountRevenueDistributionData = (dashboardData) => {
    if (!dashboardData?.charts_data?.account_revenue_distribution) {
        return {
        labels: ['Loading...'],
        datasets: [{ 
            label: 'Number of Accounts', 
            data: [0], 
            backgroundColor: 'rgba(52, 152, 219, 0.6)' 
        }]
        }
    }

    return dashboardData.charts_data.account_revenue_distribution
}

// Additional helper functions for data formatting

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
