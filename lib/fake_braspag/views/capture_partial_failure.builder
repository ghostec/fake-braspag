xml.instruct!
xml.PagadorReturn 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
  'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
  'xmlns' => 'https://www.pagador.com.br/webservice/pagador' do
  xml.amount order.amount
  xml.message 'Capture partial denied'
  xml.returnCode 2
  xml.status 2
  xml.transactionId 257575054
end
