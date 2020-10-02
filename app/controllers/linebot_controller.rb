class LinebotController < ApplicationController
  require 'line/bot'

  protect_from_forgery :except => [:callback]
  
  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      
      when Line::Bot::Event::Message #ユーザーからメッセージが送信された場合(1)
        case event.type
        #テキスト形式の場合
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: event.message['text']
          }
          client.reply_message(event['replyToken'], message)
        end
      
      when Line::Bot::Event::Follow #友だち追加された場合(2)
        #登録したユーザーのidをlinebotテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
      when Line::Bot::Event::Unfollow #ブロックしたユーザーのデータを削除(3)
        #お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private
  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
