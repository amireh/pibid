get '/transactions/:transaction_id/attachments/:attachment_id',
  auth: :user,
  requires: [ :transaction, :attachment ] do

  send_file @attachment.filepath, {
    filename: @attachment.filename,
    disposition: 'attachment'
  }
end

post '/transactions/:transaction_id/attachments',
  auth: :user,
  provides: [ :json ],
  requires: [ :transaction ] do

  @attachment = @transaction.attachments.create({
    contents: params[:file][:tempfile].read,
    filename: params[:file][:filename]
  })

  if !@attachment.saved?
    halt 400, @attachment.errors
  end

  respond_with @attachment do |f|
    f.json { rabl :"attachments/show" }
  end
end

delete '/transactions/:transaction_id/attachments/:attachment_id',
  auth: :user,
  requires: [ :transaction, :attachment ] do

  @attachment.destroy

  blank_halt! 200
end
