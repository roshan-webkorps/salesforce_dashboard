# config/routes.rb
Rails.application.routes.draw do
  # Root route - serves the React app
  root "salesforce_dashboard#index"

  # Simple API routes
  get "api/salesforce", to: "salesforce_dashboard#api_data"
  post "api/ai-query", to: "salesforce_dashboard#ai_query"   # AI Query endpoint
  post "api/reset-chat", to: "salesforce_dashboard#reset_chat"  # Reset chat context
  get "api/chat-status", to: "salesforce_dashboard#chat_status"
  get "api/health", to: "salesforce_dashboard#health_check"

  # Catch all route for React Router (if needed later)
  get "*path", to: "salesforce_dashboard#index", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
