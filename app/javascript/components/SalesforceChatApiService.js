// app/javascript/components/SalesforceChatApiService.js
class SalesforceChatApiService {
  constructor() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  }

  async sendQuery(query, appType = 'legacy', chatService = null) {
    const response = await fetch('/api/salesforce-ai-query', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        query: query,
        app_type: appType,
        chat_context: chatService
      })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
    }

    return await response.json();
  }

  async resetChat() {
    const response = await fetch('/api/salesforce-reset-chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to reset chat: ${response.statusText}`);
    }

    return await response.json();
  }

  async checkChatStatus() {
    const response = await fetch('/api/salesforce-chat-status', {
      headers: {
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json'
      }
    });
    return await response.json();
  }

  getCurrentAppType() {
    const appTypeSelect = document.querySelector('#appType');
    return appTypeSelect?.value || 'legacy';
  }

  getCurrentTimeframe() {
    const timeframeSelect = document.querySelector('#timeframe');
    return timeframeSelect?.value || '24h';
  }
}

const salesforceChatApiService = new SalesforceChatApiService();

export default salesforceChatApiService;
