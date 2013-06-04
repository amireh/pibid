namespace :pibi do
  desc "removes all stale journals"
  task :cleanup_journals => :environment do
    five_minutes = 3600 * 5
    stale = Journal.all.select { |j| j.created_at && Time.now.to_i - j.created_at.to_time.to_i >= five_minutes }

    puts "Cleaning up #{stale.length} journals."

    stale.each do |j|
      j.destroy
    end
  end
end
