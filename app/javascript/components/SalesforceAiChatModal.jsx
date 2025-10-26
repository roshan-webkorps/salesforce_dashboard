// app/javascript/components/SalesforceAiChatModal.jsx - UPDATED WITH LINE CHART SUPPORT
import React, { useState, useRef, useEffect } from 'react'
import { Bar, Doughnut, Line } from 'react-chartjs-2'
import salesforceChatApiService from './SalesforceChatApiService'

const SalesforceAiChatModal = ({ isOpen, onClose, onQuery, onNewTopic }) => {
  const [messages, setMessages] = useState([])
  const [inputValue, setInputValue] = useState('')
  const [loading, setLoading] = useState(false)
  const messagesEndRef = useRef(null)
  const inputRef = useRef(null)

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    if (isOpen && inputRef.current) {
      setTimeout(() => inputRef.current?.focus(), 100)
    }
  }, [isOpen])

  useEffect(() => {
    const clearContextOnLoad = async () => {
      try {
        const status = await salesforceChatApiService.checkChatStatus();
        if (status.has_context) {
        }
      } catch (error) {
        console.error('Failed to check chat status:', error);
      }
    };
    
    if (isOpen) {
      clearContextOnLoad();
    }
  }, [isOpen]);

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    
    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen]);

  if (!isOpen) return null

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!inputValue.trim() || loading) return

    const userMessage = inputValue.trim()
    setInputValue('')
    setLoading(true)

    const userMsgId = Date.now()
    setMessages(prev => [...prev, {
      id: userMsgId,
      type: 'user',
      content: userMessage,
      timestamp: new Date()
    }])

    try {
      const result = await onQuery(userMessage, {})
      
      const aiMsgId = Date.now() + 1
      setMessages(prev => [...prev, {
        id: aiMsgId,
        type: 'ai',
        content: result,
        timestamp: new Date()
      }])

    } catch (error) {
      console.error('Query error:', error)
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        type: 'ai',
        content: { error: error.message || 'Sorry, something went wrong. Please try again.' },
        timestamp: new Date()
      }])
    } finally {
      setLoading(false)
    }
  }

  const handleNewTopic = async () => {
    setMessages([])
    try {
      await onNewTopic()
    } catch (error) {
      console.error('Failed to reset chat:', error)
    }
    if (inputRef.current) {
      inputRef.current.focus()
    }
  }

  const handleExampleClick = (exampleQuery) => {
    setInputValue(exampleQuery)
    if (inputRef.current) {
      inputRef.current.focus()
    }
  }

  const renderChart = (data, chartType) => {
    if (!data) return null

    const chartOptions = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'top',
        },
      },
      scales: chartType === 'bar' || chartType === 'line' ? {
        y: {
          beginAtZero: true
        }
      } : undefined
    }

    const containerStyle = {
      height: '250px',
      marginBottom: '1rem'
    }

    switch (chartType) {
      case 'bar':
        return (
          <div style={containerStyle}>
            <Bar data={data} options={chartOptions} />
          </div>
        )
      case 'line':
        return (
          <div style={containerStyle}>
            <Line data={data} options={chartOptions} />
          </div>
        )
      case 'pie':
        return (
          <div style={containerStyle}>
            <Doughnut data={data} options={chartOptions} />
          </div>
        )
      default:
        return null
    }
  }

  const renderTable = (data) => {
    if (!data || !data.headers) return null

    return (
      <div className="table-container" style={{ marginBottom: '1rem' }}>
        <table className="results-table">
          <thead>
            <tr>
              {data.headers.map((header, index) => (
                <th key={index}>{header}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((row, index) => (
              <tr key={index}>
                {row.map((cell, cellIndex) => (
                  <td key={cellIndex}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )
  }

  const formatTextResponse = (text) => {
    if (!text) return <p>{text}</p>;
    
    const paragraphs = text.split(/\n\s*\n/);
    
    return paragraphs.map((paragraph, pIndex) => {
      const lines = paragraph.split('\n').filter(line => line.trim());
      
      const hasNumbers = lines.some(line => /^\d+\.\s/.test(line.trim()));
      
      if (hasNumbers) {
        const listItems = [];
        let currentItem = '';
        
        lines.forEach(line => {
          const trimmed = line.trim();
          const numberMatch = trimmed.match(/^(\d+)\.\s(.+)/);
          
          if (numberMatch) {
            if (currentItem) {
              listItems.push(currentItem);
            }
            currentItem = numberMatch[2];
          } else if (trimmed && currentItem) {
            currentItem += ' ' + trimmed;
          }
        });
        
        if (currentItem) {
          listItems.push(currentItem);
        }
        
        return (
          <ol key={pIndex} style={{ marginBottom: '1rem', paddingLeft: '1.5rem' }}>
            {listItems.map((item, index) => (
              <li key={index} style={{ marginBottom: '0.5rem', lineHeight: '1.5' }}>
                {renderBoldText(item)}
              </li>
            ))}
          </ol>
        );
      } else {
        return (
          <p key={pIndex} style={{ marginBottom: '1rem', lineHeight: '1.6' }}>
            {renderBoldText(paragraph.trim())}
          </p>
        );
      }
    });
  };

  const renderBoldText = (text) => {
    const parts = text.split(/(\*\*.*?\*\*)/g);
    
    return parts.map((part, index) => {
      if (part.startsWith('**') && part.endsWith('**')) {
        return <strong key={index}>{part.slice(2, -2)}</strong>;
      }
      return part;
    });
  };

  const renderMessage = (message) => {
    if (message.type === 'user') {
      return (
        <div key={message.id} className="message user-message">
          <div className="message-content">
            <p>{message.content}</p>
          </div>
          <div className="message-time">
            {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </div>
        </div>
      )
    }

    const content = message.content
    
    if (content.error) {
      return (
        <div key={message.id} className="message ai-message error">
          <div className="message-content">
            <p className="error-message">{content.error}</p>
            <div className="query-suggestions">
              <p><strong>Try these examples:</strong></p>
              <ul>
                <li>"Top 5 sales reps by revenue"</li>
                <li>"Show me open opportunities"</li>
                <li>"Which accounts have the highest value?"</li>
                <li>"Lead conversion rates this month"</li>
                <li>"Pipeline health by stage"</li>
              </ul>
            </div>
          </div>
          <div className="message-time">
            {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </div>
        </div>
      )
    }

    if (content.chart_type === 'text') {
      return (
        <div key={message.id} className="message ai-message">
          <div className="message-content">
            <div className="text-response">
              {formatTextResponse(content.response)}
            </div>
          </div>
          <div className="message-time">
            {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </div>
        </div>
      )
    }

    return (
      <div key={message.id} className="message ai-message">
        <div className="message-content">
          {content.chart_type === 'table' ? 
            renderTable(content.data) : 
            renderChart(content.data, content.chart_type)
          }

          {content.summary && (
            <div className="ai-summary">
              <div className="summary-content">
                {formatTextResponse(content.summary)}
              </div>
            </div>
          )}
        </div>
        <div className="message-time">
          {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>
    )
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content chat-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="chat-header-content">
            <h3>Salesforce AI Analytics Chat</h3>
            {messages.length > 0 && (
              <button 
                className="new-topic-btn"
                onClick={handleNewTopic}
                title="Start new conversation"
              >
                New Topic
              </button>
            )}
          </div>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>
        
        <div className="chat-container">
          <div className="messages-container">
            {messages.length === 0 && (
              <div className="welcome-message">
                <div className="welcome-content">
                  <h4>Hi! I'm your Salesforce analytics assistant</h4>
                  <p>Ask me anything about your sales team's performance and CRM data:</p>
                  <div className="example-queries">
                    <button 
                      className="example-query"
                      onClick={() => handleExampleClick("Top 5 sales reps by closed revenue this month")}
                    >
                      "Top 5 sales reps by closed revenue this month"
                    </button>
                    <button 
                      className="example-query"
                      onClick={() => handleExampleClick("Show me pipeline health by stage")}
                    >
                      "Show me pipeline health by stage"
                    </button>
                  </div>
                </div>
              </div>
            )}

            {messages.map(renderMessage)}

            {loading && (
              <div className="message ai-message loading">
                <div className="message-content">
                  <div className="typing-indicator">
                    <div className="spinner"></div>
                    <span>Analyzing your sales data...</span>
                  </div>
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          <div className="chat-input-container">
            <form onSubmit={handleSubmit} className="chat-form">
              <div className="input-group">
                <input
                  ref={inputRef}
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Ask about sales performance, opportunities, accounts, leads, etc..."
                  disabled={loading}
                  className="chat-input"
                />
                <button 
                  type="submit" 
                  disabled={!inputValue.trim() || loading}
                  className="send-button"
                >
                  {loading ? '⋯' : '▶'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SalesforceAiChatModal
