namespace :shownotes do
  desc "TODO"

  error = -> (msg) { puts msg; Rails.logger.error(msg) }

  process = -> (show_num, reprocess) do
    begin
      puts show_num
      Source.process!(show_num, reprocess)
    rescue => e
      raise e if Rails.env.development? && ![
        505, # Corrupted
        570, # HTTP 500
      ].include?(show_num)
      error["Problem saving show #{show_num}"]
      error[e.message]
      error[e.backtrace.join("\n")]
    end
  end

  task fetch: :environment do
    require 'net/http'

    MINIMUM_SHOW = 489 # Before that the URLs are not consistent
    NA_RSS_URL = 'http://feed.nashownotes.com/'

    response = Net::HTTP.get_response(URI.parse(NA_RSS_URL))
    feed = Nokogiri::XML(response.body)

    first_url = feed.at_css('channel > item > link').content
    last_show_number = Integer(first_url.match(/\d+/)[0])

    last_show_number.downto(MINIMUM_SHOW).each do |show_num|
      process.call show_num, false
    end
  end

  task process: :environment do
    last_show_num = Show.order(id: :desc).pluck(:id).first + 1
    while (show = Show.order(id: :desc).where('id < ?', last_show_num).first) do
      process.call show.id, true
      last_show_num = show.id
    end
  end
end
