require 'money'
require 'money/bank/google_currency'

namespace :pibi do
  desc "undoes the HTML escaping done on legacy note content"
  task :unescape_notes => :environment do
    noteful_transies = Transaction.all.reject { |tx| tx.note.empty? }

    puts "Found #{noteful_transies.length} transactions with notes, fixing..."

    noteful_transies.each { |tx|
      # puts "Fixing #{tx.note} into #{CGI::unescape(tx.note)}"
      unless tx.refresh.update!({ note: CGI::unescape(tx.note) })
        raise "Unable to update tx #{tx.id}: #{tx.errors}"
      end
      raise "Tx updating failed" if tx.refresh.note != CGI::unescape( tx.refresh.note )
    }
  end
end
