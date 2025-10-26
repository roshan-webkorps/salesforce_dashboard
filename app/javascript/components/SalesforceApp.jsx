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
import {
  OpportunityCreationTrendChart,
  WinRateAnalysisChart,
  AccountAcquisitionRevenueChart,
  PipelineHealthChart,
  DealSizeDistributionChart,
  LeadSourcePerformanceChart,
  RevenueTrendChart,
  AccountSegmentDistributionChart,
  LeadStatusFunnelChart,
  CasePriorityChart,
  SalesRepRevenueByStageChart,
  TopSalesRepsClosedWonChart,
  ClosedWonByTypeChart
} from './SalesforceChartComponents'
import { formatCurrency, formatNumber } from './SalesforceChartDataHelpers'
import SalesforceAiChatModal from './SalesforceAiChatModal'
import salesforceChatApiService from './SalesforceChatApiService'

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

const getAppUrl = (metaName, defaultUrl) => {
  const meta = document.querySelector(`meta[name="${metaName}"]`)
  return meta?.getAttribute('content') || defaultUrl
}

const SalesforceApp = () => {
  const [dashboardData, setDashboardData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [timeframe, setTimeframe] = useState('1m')
  const [appType, setAppType] = useState('legacy')
  
  const [isChatModalOpen, setIsChatModalOpen] = useState(false)

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
      setError(null)
      
      const response = await fetch(`/api/salesforce?timeframe=${timeframe}&app_type=${appType}`)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: Failed to fetch dashboard data`)
      }
      
      const data = await response.json()
      
      if (data.error) {
        throw new Error(data.error)
      }
      
      setDashboardData(data)
    } catch (err) {
      console.error('Dashboard fetch error:', err)
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

  const handleOpenChat = () => {
    setIsChatModalOpen(true)
  }

  const handleCloseChat = () => {
    setIsChatModalOpen(false)
  }

  const handleAiQuery = async (query, options = {}) => {
    try {
      const currentAppType = options.appType || appType
      const result = await salesforceChatApiService.sendQuery(query, currentAppType)
      return result
    } catch (error) {
      console.error('AI Query Error:', error)
      throw error
    }
  }

  const handleNewTopic = async () => {
    try {
      await salesforceChatApiService.resetChat()
    } catch (error) {
      console.error('Reset Chat Error:', error)
      throw error
    }
  }

  const githubUrl = getAppUrl('github-app-url', 'http://localhost:3000')
  const salesforceUrl = getAppUrl('salesforce-app-url', 'http://localhost:3002')

  if (loading) {
    return (
      <div className="loading-container">
        <h2>Loading Salesforce Dashboard...</h2>
        <p>Fetching sales growth metrics...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="error-container">
        <h2>Error Loading Dashboard</h2>
        <p>{error}</p>
        <button onClick={fetchDashboardData} className="retry-btn">
          Retry Loading
        </button>
      </div>
    )
  }

  return (
    <div className="app">
      <nav className="app-navigation">
        <div className="nav-links">
          <a href={githubUrl} className="nav-link">
            GitHub & Jira Analytics
          </a>
          <a href={salesforceUrl} className="nav-link active">
            Salesforce Analytics
          </a>
        </div>
      </nav>

      <header className="app-header">
        <div className="header-content">
          <div className="header-left">
            <h1>Salesforce Dashboard</h1>
          </div>
          
          <div className="header-center">
            <button className="open-chat-btn" onClick={handleOpenChat}>
              <span className="search-icon">🔍</span>
              Ask AI about your sales data...
            </button>
          </div>
          
          <div className="header-right">
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
          <h2 className="charts-title">Sales Growth Analytics</h2>

          <div className="charts-grid-full">
            <SalesRepRevenueByStageChart dashboardData={dashboardData} />
          </div>

          <div className="charts-grid-two">
            <TopSalesRepsClosedWonChart dashboardData={dashboardData} />
            <ClosedWonByTypeChart dashboardData={dashboardData} />
          </div>

          <div className="charts-grid-two">
            <OpportunityCreationTrendChart dashboardData={dashboardData} />
            <WinRateAnalysisChart dashboardData={dashboardData} />
          </div>

          <div className="charts-grid-two">
            <AccountAcquisitionRevenueChart dashboardData={dashboardData} />
            <RevenueTrendChart dashboardData={dashboardData} />
          </div>

          <div className="charts-grid-two">
            <PipelineHealthChart dashboardData={dashboardData} />
            <LeadSourcePerformanceChart dashboardData={dashboardData} />
          </div>

          <div className="charts-grid-two">
            <DealSizeDistributionChart dashboardData={dashboardData} />
            <LeadStatusFunnelChart dashboardData={dashboardData} />
          </div>
        </div>
      </main>

      <SalesforceAiChatModal
        isOpen={isChatModalOpen}
        onClose={handleCloseChat}
        onQuery={handleAiQuery}
        onNewTopic={handleNewTopic}
      />
    </div>
  )
}

export default SalesforceApp
