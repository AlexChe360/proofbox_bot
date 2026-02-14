#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# ProofBox RevenueCat → Telegram Webhook Server
# ==============================================================================
#
# БЫСТРАЯ НАСТРОЙКА:
#
# 1. Создайте Telegram бота:
#    - Откройте @BotFather в Telegram
#    - Отправьте /newbot
#    - Скопируйте токен бота
#
# 2. Получите Chat ID:
#    - Откройте @userinfobot в Telegram
#    - Отправьте /start
#    - Скопируйте ваш ID
#
# 3. Установите зависимости:
#    gem install sinatra puma
#
# 4. Запустите сервер:
#    TELEGRAM_BOT_TOKEN=ваш_токен TELEGRAM_CHAT_ID=ваш_id ruby webhook.rb
#
# 5. Для деплоя используйте Railway.app, Render.com или Heroku
#
# ==============================================================================

require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

# Конфигурация из переменных окружения
TELEGRAM_BOT_TOKEN = ENV['TELEGRAM_BOT_TOKEN'] || 'YOUR_BOT_TOKEN_HERE'
TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID'] || 'YOUR_CHAT_ID_HERE'

set :port, ENV['PORT'] || 4567
set :bind, '0.0.0.0'

# Главный endpoint для RevenueCat webhook
post '/webhook' do
  content_type :json

  begin
    request.body.rewind
    payload = JSON.parse(request.body.read)

    event = payload['event']
    event_type = event['type']
    product_id = event['product_id'] || 'N/A'
    store = event['store'] || 'N/A'
    country = event['country_code'] || 'N/A'
    environment = event['environment'] || 'N/A'
    user_id = event['app_user_id'] || 'N/A'

    # Эмодзи для разных типов событий
    emoji = case event_type
            when 'INITIAL_PURCHASE' then '🎉'
            when 'RENEWAL' then '🔄'
            when 'CANCELLATION' then '❌'
            when 'BILLING_ISSUE' then '⚠️'
            when 'NON_RENEWING_PURCHASE' then '💵'
            when 'PRODUCT_CHANGE' then '🔀'
            when 'TEST' then '🧪'
            else '💰'
            end

    # Формируем красивое сообщение
    message = <<~TEXT
      #{emoji} <b>#{event_type}</b> в ProofBox!

      🏪 Магазин: #{store}
      🌍 Страна: #{country}
      🔧 Среда: #{environment}
      📦 Продукт: #{product_id}
      👤 User ID: <code>#{user_id[0..10]}...</code>
    TEXT

    send_telegram_message(message)

    puts "[#{Time.now}] ✅ #{event_type} from #{store} (#{environment})"

    { status: 'ok' }.to_json

  rescue JSON::ParserError => e
    puts "[#{Time.now}] ❌ Invalid JSON: #{e.message}"
    status 400
    { status: 'error', message: 'Invalid JSON' }.to_json

  rescue => e
    puts "[#{Time.now}] ❌ Error: #{e.message}"
    status 500
    { status: 'error', message: e.message }.to_json
  end
end

# Проверка что сервер работает
get '/' do
  if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE'
    halt 500, "⚠️ Configure TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID\n\nSee instructions at the top of this file"
  end

  'ProofBox Webhook Server is running! 🚀'
end

# Тестовый endpoint
get '/test' do
  if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE'
    halt 500, "⚠️ Configure TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
  end

  test_message = "🧪 <b>Test notification</b>\n\nServer: ProofBox Webhook\nTime: #{Time.now}"

  if send_telegram_message(test_message)
    'Test notification sent! Check Telegram ✅'
  else
    'Failed to send notification ❌'
  end
end

# Отправка сообщения в Telegram
def send_telegram_message(text)
  return false if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE'

  uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_TOKEN}/sendMessage")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 10

  request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  request.body = {
    chat_id: TELEGRAM_CHAT_ID,
    text: text,
    parse_mode: 'HTML'
  }.to_json

  response = http.request(request)

  if response.code == '200'
    puts "[#{Time.now}] 📱 Telegram sent"
    true
  else
    puts "[#{Time.now}] ❌ Telegram error: #{response.body}"
    false
  end
rescue => e
  puts "[#{Time.now}] ❌ Failed: #{e.message}"
  false
end
