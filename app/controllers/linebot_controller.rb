class LinebotController < ApplicationController
  require 'line/bot'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

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
        when Line::Bot::Event::MessageType::Text
          url = "https://www.drk7.jp/weather/xml/13.xml"
          xml = open(url).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          case event.message['text']

          when /.*(今日|きょう).*/
            # info[1] => 今日の降水確率
            per06to12 = doc.elements[xpath + 'info[1]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[1]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[1]/rainfallchance/period[4]'].text
            content = "今日の降水確率。\n\n【降水確率】\n  6〜12時 #{per06to12}％\n 12〜18時 #{per12to18}％\n 18〜24時 #{per18to24}％"
          when /.*(明日|あした).*/
            # info[2] => 明日の降水確率
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            content = "明日の降水確率。\n\n【降水確率】\n  6〜12時 #{per06to12}％\n 12〜18時 #{per12to18}％\n 18〜24時 #{per18to24}％"
          when /.*(明後日|あさって).*/
            # info[3] => 明後日の降水確率
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
            content = "明後日の降水確率。\n\n【降水確率】\n  6〜12時 #{per06to12}％\n 12〜18時 #{per12to18}％\n 18〜24時 #{per18to24}％"
          when /.*(可愛い|かわいい|ありがとう|こんにちは).*/
            content = "♪"
          end
        # テキスト形式以外（画像等）の場合
        else
          content = "？（今日、明日、明後日のどれかを入力してね）"
        end

        message = {
          type: 'text',
          text: content
        }
        client.reply_message(event['replyToken'], message)

      when Line::Bot::Event::Follow #友だち追加された
        line_id = event['source']['userId']
        User.create(line_id: line_id)
      when Line::Bot::Event::Unfollow #ブロックされた
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
