// app/javascript/components/SalesforceApp.jsx
import React, { useState, useEffect } from 'react'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  LineElement,
  PointElement,
  Title,
  Tooltip,
  Legend,
  Filler
} from 'chart.js'
// import AiChatModal from './AiChatModal'  // Add when implementing AI chat
// import chatApiService from './chatApiService'  // Add when implementing AI chat
import {
  RevenueByRepChart,
  SalesPipelineChart,
  MonthlyRevenueTrendChart,
  RevenueByIndustryChart,
  CasePriorityChart,
  AccountRevenueDistributionChart
} from './SalesforceChartComponents'
import { formatCurrency, formatNumber } from './SalesforceChartDataHelpers'

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  LineElement,
  PointElement,
  Title,
  Tooltip,
  Legend,
  Filler
)

const SalesforceApp = () => {
  const [dashboardData, setDashboardData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [timeframe, setTimeframe] = useState('24h')  // Default to 24 hours
  const [appType, setAppType] = useState('legacy')
  
  // AI Chat states - Add when implementing AI chat
  // const [isChatOpen, setIsChatOpen] = useState(false)

  const timeframeOptions = [
    { value: '24h', label: '24 Hours' },
    { value: '7d', label: '7 Days' },
    { value: '1m', label: '1 Month' },
    { value: '6m', label: '6 Months' },
    { value: '1y', label: '1 Year' }
  ]

  const appTypeOptions = [
    { value: 'legacy', label: 'Legacy App' },
    { value: 'pioneer', label: 'Pioneer App' }
  ]

  useEffect(() => {
    fetchDashboardData()
  }, [timeframe, appType])

  const fetchDashboardData = async () => {
    try {
      setLoading(true)
      const response = await fetch(`/api/salesforce?timeframe=${timeframe}&app_type=${appType}`)
      if (!response.ok) {
        throw new Error('Failed to fetch salesforce dashboard data')
      }
      const data = await response.json()
      setDashboardData(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleTimeframeChange = (newTimeframe) => {
    setTimeframe(newTimeframe)
  }

  const handleAppTypeChange = (newAppType) => {
    setAppType(newAppType)
  }

  // AI Chat handlers - Add when implementing AI chat
  // const handleOpenChat = () => {
  //   setIsChatOpen(true)
  // }

  // const handleCloseChat = () => {
  //   setIsChatOpen(false)
  // }

  if (loading) {
    return (
      <div className="loading-container">
        <h2>Loading Salesforce Dashboard...</h2>
      </div>
    )
  }

  if (error) {
    return (
      <div className="error-container">
        <h2>Error</h2>
        <p>{error}</p>
        <button onClick={fetchDashboardData} className="retry-btn">
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-content">
          <div className="header-text">
            <h1>Salesforce Dashboard</h1>
          </div>
          
          {/* AI Chat Button - Add when implementing AI chat */}
          <div className="search-section">
            <button 
              className="open-chat-btn"
              // onClick={handleOpenChat}
            >
              <span className="search-icon">🔍</span>
              Ask AI about your sales data...
            </button>
          </div>
          
          <div className="controls-section">
            <div className="app-type-selector">
              <label htmlFor="appType">App Type:</label>
              <select 
                id="appType"
                value={appType} 
                onChange={(e) => handleAppTypeChange(e.target.value)}
                className="app-type-select"
              >
                {appTypeOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            
            <div className="timeframe-selector">
              <label htmlFor="timeframe">Timeframe:</label>
              <select 
                id="timeframe"
                value={timeframe} 
                onChange={(e) => handleTimeframeChange(e.target.value)}
                className="timeframe-select"
              >
                {timeframeOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>
      </header>
      
      <main className="app-main">
        {dashboardData?.summary && (
          <div className="stats-grid">
            <div className="stat-card">
              <h3>Active Sales Reps</h3>
              <p className="stat-number">{formatNumber(dashboardData.summary.total_sales_reps)}</p>
              <p className="stat-label">Contributors</p>
            </div>
            
            <div className="stat-card">
              <h3>Total Accounts</h3>
              <p className="stat-number">{formatNumber(dashboardData.summary.total_accounts)}</p>
              <p className="stat-label">Customers</p>
            </div>
            
            <div className="stat-card">
              <h3>Open Opportunities</h3>
              <p className="stat-number">{formatNumber(dashboardData.summary.total_open_opportunities)}</p>
              <p className="stat-label">In Pipeline</p>
            </div>
            
            <div className="stat-card">
              <h3>Total Revenue</h3>
              <p className="stat-number">{formatCurrency(dashboardData.summary.total_revenue)}</p>
              <p className="stat-label">in {timeframeOptions.find(t => t.value === timeframe)?.label}</p>
            </div>
            
            <div className="stat-card">
              <h3>Support Cases</h3>
              <p className="stat-number">{formatNumber(dashboardData.summary.total_cases)}</p>
              <p className="stat-label">in {timeframeOptions.find(t => t.value === timeframe)?.label}</p>
            </div>
          </div>
        )}

        <div className="charts-section">
          <h2>Sales Analytics Overview</h2>
          
          {/* Row 1: Revenue Performance */}
          <div className="charts-grid-two">
            <RevenueByRepChart dashboardData={dashboardData} />
            <SalesPipelineChart dashboardData={dashboardData} />
          </div>

          {/* Row 2: Revenue Trends */}
          <div className="charts-grid-two">
            <MonthlyRevenueTrendChart dashboardData={dashboardData} />
            <AccountRevenueDistributionChart dashboardData={dashboardData} />
          </div>

          {/* Row 3: Revenue Analysis */}
          <div className="charts-grid-two">
            <RevenueByIndustryChart dashboardData={dashboardData} />
            <CasePriorityChart dashboardData={dashboardData} />
          </div>
        </div>
      </main>
      
      {/* AI Chat Modal - Add when implementing AI chat */}
      {/* <AiChatModal
        isOpen={isChatOpen}
        onClose={handleCloseChat}
        onQuery={handleChatQuery}
        onNewTopic={handleNewTopic}
      /> */}
    </div>
  )
}

export default SalesforceApp
