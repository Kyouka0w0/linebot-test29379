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
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']

          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'

          min_per = 30
          case input
          when /.*(明日|あした).*/
            weather = doc.elements[xpath + 'info[2]/weather'].text
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気は #{weather} \n 傘が必要かも\n 現在の降水確率\n 6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}％\n 18〜24時 #{per18to24}％"
            else
              push =
                "明日の天気は #{weather} \n 雨は降らないと思う"
            end
          when /.*(明後日|あさって).*/
            weather = doc.elements[xpath + 'info[3]/weather'].text
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気は #{weather}、傘が必要みたい"
            else
              push =
                "明後日の天気は #{weather} \n 雨は降らないと思う"
            end
          when /.*(可愛い|かわいい|好き|すき).*/
            push =
              "♪"
          else
            weather = doc.elements[xpath + 'info/weather'].text
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "今日天気は #{weather} \n 傘を持っていってね \n 降水確率は\n 6〜12時 #{per06to12}％\n 12〜18時 #{per12to18}％\n 18〜24時 #{per18to24}％"
            else
              push =
                "今日天気は #{weather} \n 雨は降らなさそう"
            end
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "？"
        end

        message = {
          type: 'text',
          text: push
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
