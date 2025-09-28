env :PATH, ENV["PATH"]
set :environment, ENV["RAILS_ENV"]
set :output, "log/cron.log"

every 6.hours do
  rake "salesforce:legacy:incremental_sync"
end
